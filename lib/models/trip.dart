import 'package:cloud_firestore/cloud_firestore.dart';

/// Transport mode between stops.
enum TransportType { drive, flight, train, ferry, unknown }

TransportType parseTransportType(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'drive':
      return TransportType.drive;
    case 'flight':
      return TransportType.flight;
    case 'train':
      return TransportType.train;
    case 'ferry':
      return TransportType.ferry;
    default:
      return TransportType.unknown;
  }
}

/// A location on the trip route.
class TripLocation {
  final String name;
  final double lat;
  final double lng;
  final TransportType transportType;
  final bool isOvernight; // hotel / camp stop

  const TripLocation({
    required this.name,
    required this.lat,
    required this.lng,
    this.transportType = TransportType.unknown,
    this.isOvernight = false,
  });

  factory TripLocation.fromMap(Map<String, dynamic> m) => TripLocation(
        name: m['name'] as String? ?? '',
        lat: (m['lat'] as num?)?.toDouble() ?? 0.0,
        lng: (m['lng'] as num?)?.toDouble() ?? 0.0,
        transportType: parseTransportType(m['transport_type'] as String?),
        isOvernight: m['is_overnight'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'lat': lat,
        'lng': lng,
        'transport_type': transportType.name,
        'is_overnight': isOvernight,
      };
}

/// Member role within a trip.
enum TripRole { admin, member }

/// Represents a single Rihla trip stored in Firestore.
class Trip {
  Trip({
    required this.id,
    required this.title,
    required this.adminId,
    required this.joinCode,
    this.description = '',
    this.itinerary = const [],
    this.locations = const [],
    this.transportSuggestions = const [],
    this.members = const {},
    this.isPublic = false,
    this.paidMembers = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;
  final String description;

  /// The original creator of the trip — cannot be removed or demoted.
  final String adminId;
  final String joinCode;
  final List<String> itinerary;
  final List<TripLocation> locations;
  final List<String> transportSuggestions;

  /// uid -> 'admin' | 'member'
  final Map<String, String> members;
  final bool isPublic;
  final List<String> paidMembers;
  final DateTime createdAt;

  // ── Firestore serialisation ─────────────────

  factory Trip.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return Trip(
      id: doc.id,
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      adminId: d['admin_id'] ?? '',
      joinCode: d['join_code'] ?? '',
      itinerary: List<String>.from(d['itinerary'] ?? []),
      locations: (d['locations'] as List<dynamic>?)
              ?.map((e) => TripLocation.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      transportSuggestions:
          List<String>.from(d['transport_suggestions'] ?? []),
      members: Map<String, String>.from(d['members'] ?? {}),
      isPublic: d['is_public'] ?? false,
      paidMembers: List<String>.from(d['paid_members'] ?? []),
      createdAt:
          (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'description': description,
        'admin_id': adminId,
        'join_code': joinCode,
        'itinerary': itinerary,
        'locations': locations.map((l) => l.toMap()).toList(),
        'transport_suggestions': transportSuggestions,
        'members': members,
        'is_public': isPublic,
        'paid_members': paidMembers,
        'created_at': Timestamp.fromDate(createdAt),
      };

  // ═════════════════════════════════════════════
  //  Role & Permission Helpers
  // ═════════════════════════════════════════════

  /// Whether [uid] is the original trip creator.
  bool isCreator(String uid) => uid == adminId;

  /// Whether [uid] has the admin role (including the creator).
  bool isAdmin(String uid) =>
      uid == adminId || members[uid] == 'admin';

  /// Whether [uid] has any access to this trip.
  bool hasAccess(String uid) =>
      uid == adminId || paidMembers.contains(uid);

  /// Can [actorUid] remove [targetUid] from the trip?
  ///
  /// Rules:
  /// - Creator can never be removed.
  /// - Creator can remove anyone (admins + members).
  /// - Admins can remove regular members but NOT other admins.
  /// - Regular members cannot remove anyone.
  bool canRemove(String actorUid, String targetUid) {
    if (targetUid == adminId) return false; // creator is untouchable
    if (actorUid == targetUid) return false; // can't remove yourself
    if (actorUid == adminId) return true; // creator can remove anyone
    if (isAdmin(actorUid) && !isAdmin(targetUid)) return true; // admin removes member
    return false;
  }

  /// Can [actorUid] promote [targetUid] to admin?
  ///
  /// Rules:
  /// - Only admins can promote.
  /// - Can't promote someone who's already admin.
  bool canPromote(String actorUid, String targetUid) {
    if (!isAdmin(actorUid)) return false; // only admins can promote
    if (isAdmin(targetUid)) return false; // already admin
    return true;
  }

  /// Can [actorUid] demote [targetUid] from admin to member?
  ///
  /// Rules:
  /// - Only the creator can demote admins.
  /// - Creator can never be demoted.
  bool canDemote(String actorUid, String targetUid) {
    if (actorUid != adminId) return false; // only creator can demote
    if (targetUid == adminId) return false; // creator can't be demoted
    if (!isAdmin(targetUid)) return false; // target isn't admin
    return true;
  }

  /// Whether [actorUid] can see manage actions (promote/remove/demote)
  /// for any member at all.
  bool canManageMembers(String actorUid) => isAdmin(actorUid);

  // ── copyWith ──────────────────────────────────

  Trip copyWith({
    String? title,
    String? description,
    List<String>? itinerary,
    List<TripLocation>? locations,
    List<String>? transportSuggestions,
    Map<String, String>? members,
    bool? isPublic,
    List<String>? paidMembers,
  }) =>
      Trip(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        adminId: adminId,
        joinCode: joinCode,
        itinerary: itinerary ?? this.itinerary,
        locations: locations ?? this.locations,
        transportSuggestions:
            transportSuggestions ?? this.transportSuggestions,
        members: members ?? this.members,
        isPublic: isPublic ?? this.isPublic,
        paidMembers: paidMembers ?? this.paidMembers,
        createdAt: createdAt,
      );
}
