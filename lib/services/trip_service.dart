import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/trip.dart';
import 'ai_service.dart';

/// Thin wrapper around Firestore for Trip documents.
class TripService {
  TripService._();
  static final TripService instance = TripService._();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _trips =>
      _db.collection('trips');

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  // ── Name resolution cache ─────────────────────
  final Map<String, String> _nameCache = {};

  /// Resolve a list of UIDs to their display names from the `users` collection.
  /// Results are cached in memory to avoid repeated Firestore reads.
  Future<Map<String, String>> resolveNames(List<String> uids) async {
    final result = <String, String>{};
    final toFetch = <String>[];

    for (final uid in uids) {
      if (_nameCache.containsKey(uid)) {
        result[uid] = _nameCache[uid]!;
      } else {
        toFetch.add(uid);
      }
    }

    for (final uid in toFetch) {
      try {
        final doc = await _db.collection('users').doc(uid).get();
        final data = doc.data();
        // Check both snake_case (used by auth_service) and camelCase (legacy)
        final name =
            (data?['display_name'] as String?)?.isNotEmpty == true
                ? data!['display_name'] as String
                : (data?['displayName'] as String?)?.isNotEmpty == true
                    ? data!['displayName'] as String
                    : 'Member ${uid.length >= 6 ? uid.substring(0, 6) : uid}';
        _nameCache[uid] = name;
        result[uid] = name;
      } catch (_) {
        final fallback =
            'Member ${uid.length >= 6 ? uid.substring(0, 6) : uid}';
        _nameCache[uid] = fallback;
        result[uid] = fallback;
      }
    }

    return result;
  }

  /// Get a cached name for a UID (returns short UID if not cached).
  String getCachedName(String uid) {
    return _nameCache[uid] ??
        (uid.length >= 6 ? uid.substring(0, 6) : uid);
  }

  /// Force re-fetch names on next call (clears stale cache).
  void clearNameCache() => _nameCache.clear();

  // ── Real-time trip stream ─────────────────────
  Stream<Trip?> tripStream(String tripId) {
    return _trips.doc(tripId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return Trip.fromFirestore(snap);
    });
  }

  String _generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── Create trip ─────────────────────────────
  Future<Trip> createTrip({
    required String title,
    String description = '',
    List<String> itinerary = const [],
    List<TripLocation> locations = const [],
    List<String> transportSuggestions = const [],
    DateTime? startDate,
    DateTime? endDate,
    List<DayAgenda> dailyAgenda = const [],
  }) async {
    final code = _generateJoinCode();
    final now = DateTime.now();

    String? formatDate(DateTime? d) =>
        d != null
            ? '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'
            : null;

    // Build the plain Map ourselves — no FieldValue.serverTimestamp()
    // so the write works instantly even without server connectivity.
    final data = <String, dynamic>{
      'title': title,
      'description': description,
      'admin_id': _uid,
      'join_code': code,
      'itinerary': itinerary,
      'locations': locations.map((l) => l.toMap()).toList(),
      'transport_suggestions': transportSuggestions,
      if (startDate != null) 'start_date': formatDate(startDate),
      if (endDate != null) 'end_date': formatDate(endDate),
      'daily_agenda': dailyAgenda.map((e) => e.toMap()).toList(),
      'members': {_uid: 'admin'},
      'is_public': false,
      'paid_members': [_uid],
      'created_at': Timestamp.fromDate(now),
    };

    debugPrint('[TripService] Attempting to save trip "$title" to Firestore...');
    debugPrint('[TripService] Collection: trips | Admin UID: $_uid');
    debugPrint('[TripService] Data keys: ${data.keys.join(', ')}');

    try {
      final docRef = await _trips
          .add(data)
          .timeout(const Duration(seconds: 10));

      debugPrint('[TripService] Firestore Success! Doc ID: ${docRef.id}');

      // Build the Trip locally — don't re-fetch from server.
      return Trip(
        id: docRef.id,
        title: title,
        description: description,
        adminId: _uid,
        joinCode: code,
        itinerary: itinerary,
        locations: locations,
        transportSuggestions: transportSuggestions,
        startDate: startDate,
        endDate: endDate,
        dailyAgenda: dailyAgenda,
        members: {_uid: 'admin'},
        isPublic: false,
        paidMembers: [_uid],
        createdAt: now,
      );
    } on TimeoutException {
      debugPrint('[TripService] Firestore TIMEOUT after 10 seconds');
      throw Exception('Save timed out — check your internet connection.');
    } catch (e) {
      debugPrint('[TripService] Firestore Error: $e');
      rethrow;
    }
  }

  /// Create a trip directly from an [AiTripResult].
  Future<Trip> createFromAiResult(AiTripResult result,
      {String description = ''}) {
    debugPrint('[TripService] createFromAiResult: "${result.tripTitle}"');
    debugPrint('[TripService]   locations: ${result.locations.length}');
    debugPrint('[TripService]   transport: ${result.transportSuggestions.length}');
    debugPrint('[TripService]   itinerary: ${result.dailyItinerary.length}');
    debugPrint('[TripService]   dailyAgenda: ${result.dailyAgenda.length}');

    DateTime? parseDate(String? s) => s != null && s.isNotEmpty ? DateTime.tryParse(s) : null;

    final startDate = parseDate(result.tripStartDate);
    final endDate = parseDate(result.tripEndDate);

    final dailyAgenda = result.dailyAgenda
        .map((a) => DayAgenda(
              dayIndex: a.dayIndex,
              date: a.date,
              city: a.city,
              pois: a.pois
                  .map((p) => PoiItem(
                        name: p.name,
                        description: p.description,
                        lat: p.lat,
                        lng: p.lng,
                        searchQuery: p.searchQuery,
                      ))
                  .toList(),
            ))
        .toList();

    return createTrip(
      title: result.tripTitle,
      description: description,
      itinerary: result.dailyItinerary,
      locations: result.locations
          .map((l) => TripLocation(
                name: l.name,
                lat: l.lat,
                lng: l.lng,
                transportType: parseTransportType(l.transportType),
                isOvernight: l.isOvernight,
              ))
          .toList(),
      transportSuggestions: result.transportSuggestions,
      startDate: startDate,
      endDate: endDate,
      dailyAgenda: dailyAgenda,
    );
  }

  // ── Read by ID ──────────────────────────────
  Future<Trip?> getTrip(String tripId) async {
    final snap = await _trips.doc(tripId).get().timeout(const Duration(seconds: 10));
    if (!snap.exists) return null;
    return Trip.fromFirestore(snap);
  }

  // ── Find by join code ───────────────────────
  Future<Trip?> findByJoinCode(String code) async {
    final snap = await _trips
        .where('join_code', isEqualTo: code.toUpperCase().trim())
        .limit(1)
        .get()
        .timeout(const Duration(seconds: 10));
    if (snap.docs.isEmpty) return null;
    return Trip.fromFirestore(snap.docs.first);
  }

  // ── Mark trip as public ─────────────────────
  Future<void> markPublic(String tripId) async {
    await _trips.doc(tripId).update({
      'is_public': true,
      'paid_members': FieldValue.arrayUnion([_uid]),
    }).timeout(const Duration(seconds: 10));
  }

  // ── Add a paid member ───────────────────────
  Future<void> addPaidMember(String tripId) async {
    await _trips.doc(tripId).update({
      'paid_members': FieldValue.arrayUnion([_uid]),
      'members.$_uid': 'member',
    }).timeout(const Duration(seconds: 10));
  }

  // ── Promote member to admin ─────────────────
  Future<void> promoteToAdmin(String tripId, String memberId) async {
    await _trips.doc(tripId).update({
      'members.$memberId': 'admin',
    }).timeout(const Duration(seconds: 10));
  }

  // ── Demote admin to regular member ────────────
  Future<void> demoteToMember(String tripId, String memberId) async {
    await _trips.doc(tripId).update({
      'members.$memberId': 'member',
    }).timeout(const Duration(seconds: 10));
  }

  // ── Remove a member from trip ─────────────────
  Future<void> removeMember(String tripId, String memberId) async {
    await _trips.doc(tripId).update({
      'paid_members': FieldValue.arrayRemove([memberId]),
      'members.$memberId': FieldValue.delete(),
    }).timeout(const Duration(seconds: 10));
  }

  // ── Update trip title ─────────────────────────
  Future<void> updateTitle(String tripId, String newTitle) async {
    await _trips.doc(tripId).update({
      'title': newTitle,
    }).timeout(const Duration(seconds: 10));
  }

  // ── Delete a location from trip ───────────────
  Future<void> removeLocation(String tripId, List<TripLocation> updatedLocations) async {
    await _trips.doc(tripId).update({
      'locations': updatedLocations.map((l) => l.toMap()).toList(),
    }).timeout(const Duration(seconds: 10));
  }

  // ── Settle / Unsettle trip kitty ────────────
  Future<void> settleTrip(String tripId) async {
    await _trips.doc(tripId).update({
      'is_settled': true,
      'settled_at': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 10));
  }

  Future<void> unsettleTrip(String tripId) async {
    await _trips.doc(tripId).update({
      'is_settled': false,
      'settled_at': FieldValue.delete(),
    }).timeout(const Duration(seconds: 10));
  }

  // ── My trips ────────────────────────────────
  Future<List<Trip>> myTrips() async {
    debugPrint('[TripService] myTrips() called for UID: $_uid');
    try {
      // Simple queries without orderBy — avoids needing composite indexes.
      // We sort locally instead.
      final adminSnap = await _trips
          .where('admin_id', isEqualTo: _uid)
          .get()
          .timeout(const Duration(seconds: 10));
      debugPrint('[TripService] adminSnap: ${adminSnap.docs.length} docs');

      final memberSnap = await _trips
          .where('paid_members', arrayContains: _uid)
          .get()
          .timeout(const Duration(seconds: 10));
      debugPrint('[TripService] memberSnap: ${memberSnap.docs.length} docs');

      final map = <String, Trip>{};
      for (final doc in [...adminSnap.docs, ...memberSnap.docs]) {
        map.putIfAbsent(doc.id, () => Trip.fromFirestore(doc));
      }
      final list = map.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      debugPrint('[TripService] myTrips returning ${list.length} trips');
      return list;
    } catch (e) {
      debugPrint('[TripService] myTrips ERROR: $e');
      rethrow;
    }
  }

  // ── Access checks ───────────────────────────
  bool currentUserHasAccess(Trip trip) => trip.hasAccess(_uid);
  bool currentUserIsAdmin(Trip trip) => trip.isAdmin(_uid);
  String get currentUserId => _uid;
}
