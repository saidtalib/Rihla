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
  final String adminId;
  final String joinCode;
  final List<String> itinerary;
  final List<TripLocation> locations;
  final List<String> transportSuggestions;
  final Map<String, String> members; // uid -> 'admin' | 'member'
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
      createdAt: (d['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
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

  // ── Helpers ─────────────────────────────────

  bool hasAccess(String uid) =>
      uid == adminId || paidMembers.contains(uid);

  bool isAdmin(String uid) =>
      uid == adminId || members[uid] == 'admin';

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
