import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// One member's live location shared with the Pack.
class LiveLocationEntry {
  const LiveLocationEntry({
    required this.uid,
    required this.lat,
    required this.lng,
    required this.displayName,
    this.photoUrl,
    required this.updatedAt,
  });

  final String uid;
  final double lat;
  final double lng;
  final String displayName;
  final String? photoUrl;
  final DateTime updatedAt;

  static LiveLocationEntry fromMap(String uid, Map<String, dynamic> data) {
    return LiveLocationEntry(
      uid: uid,
      lat: (data['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0.0,
      displayName: data['display_name'] as String? ?? '',
      photoUrl: data['photo_url'] as String?,
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Manages sharing and reading live locations for a trip (the Pack).
class LiveLocationService {
  LiveLocationService._();
  static final LiveLocationService instance = LiveLocationService._();

  final _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _liveRef(String tripId) =>
      _db.collection('trips').doc(tripId).collection('live_locations');

  /// Stream of all members currently sharing their location for this trip.
  Stream<List<LiveLocationEntry>> streamLiveLocations(String tripId) {
    return _liveRef(tripId).snapshots().map((snap) {
      return snap.docs
          .map((doc) => LiveLocationEntry.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  /// Write or update the current user's live location. Call throttled (e.g. every 15s or when position changes significantly).
  Future<void> setMyLiveLocation(
    String tripId, {
    required double lat,
    required double lng,
    required String displayName,
    String? photoUrl,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    await _liveRef(tripId).doc(uid).set({
      'lat': lat,
      'lng': lng,
      'display_name': displayName,
      'photo_url': photoUrl ?? '',
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Stop sharing: remove the current user's live location doc.
  Future<void> clearMyLiveLocation(String tripId) async {
    final uid = _uid;
    if (uid == null) return;

    await _liveRef(tripId).doc(uid).delete();
  }
}
