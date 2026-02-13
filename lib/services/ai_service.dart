import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// A single point of interest for one day.
class AiPoiItem {
  final String name;
  final String? description;
  final double? lat;
  final double? lng;
  final String? searchQuery;

  const AiPoiItem({
    required this.name,
    this.description,
    this.lat,
    this.lng,
    this.searchQuery,
  });

  factory AiPoiItem.fromJson(Map<String, dynamic> json) {
    final lat = json['lat'];
    final lng = json['lng'];
    return AiPoiItem(
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      lat: lat != null ? (lat is num ? lat.toDouble() : double.tryParse(lat.toString())) : null,
      lng: lng != null ? (lng is num ? lng.toDouble() : double.tryParse(lng.toString())) : null,
      searchQuery: json['search_query'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (searchQuery != null) 'search_query': searchQuery,
      };
}

/// One day in the agenda with city and POIs.
class AiDayAgenda {
  final int dayIndex;
  final String? date; // YYYY-MM-DD optional
  final String? city;
  final List<AiPoiItem> pois;

  const AiDayAgenda({
    required this.dayIndex,
    this.date,
    this.city,
    this.pois = const [],
  });

  factory AiDayAgenda.fromJson(Map<String, dynamic> json) {
    final poisList = json['pois'] as List<dynamic>?;
    return AiDayAgenda(
      dayIndex: (json['day_index'] as num?)?.toInt() ?? 0,
      date: json['date'] as String?,
      city: json['city'] as String?,
      pois: poisList
              ?.map((e) => AiPoiItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'day_index': dayIndex,
        if (date != null) 'date': date,
        if (city != null) 'city': city,
        'pois': pois.map((e) => e.toJson()).toList(),
      };
}

/// Structured result returned by the AI trip planner.
class AiTripResult {
  final String tripTitle;
  final List<AiLocation> locations;
  final List<String> transportSuggestions;
  final List<String> dailyItinerary;
  final String? tripStartDate; // YYYY-MM-DD
  final String? tripEndDate;   // YYYY-MM-DD
  final List<AiDayAgenda> dailyAgenda;

  const AiTripResult({
    required this.tripTitle,
    required this.locations,
    required this.transportSuggestions,
    required this.dailyItinerary,
    this.tripStartDate,
    this.tripEndDate,
    this.dailyAgenda = const [],
  });

  factory AiTripResult.fromJson(Map<String, dynamic> json) {
    final agendaList = json['daily_agenda'] as List<dynamic>?;
    return AiTripResult(
      tripTitle: json['trip_title'] as String? ?? 'Untitled Trip',
      locations: (json['locations'] as List<dynamic>?)
              ?.map((e) => AiLocation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      transportSuggestions:
          (json['transportation_suggestions'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
      dailyItinerary: (json['daily_itinerary'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      tripStartDate: json['trip_start_date'] as String?,
      tripEndDate: json['trip_end_date'] as String?,
      dailyAgenda: agendaList
              ?.map((e) => AiDayAgenda.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class AiLocation {
  final String name;
  final double lat;
  final double lng;
  final String transportType; // drive, flight, train, ferry
  final bool isOvernight;

  const AiLocation({
    required this.name,
    required this.lat,
    required this.lng,
    this.transportType = 'drive',
    this.isOvernight = false,
  });

  factory AiLocation.fromJson(Map<String, dynamic> json) {
    return AiLocation(
      name: json['name'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      transportType: json['transport_type'] as String? ?? 'drive',
      isOvernight: json['is_overnight'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'lat': lat,
        'lng': lng,
        'transport_type': transportType,
        'is_overnight': isOvernight,
      };
}

/// Gemini-powered AI service for trip planning.
class AiService {
  AiService._();
  static final AiService instance = AiService._();

  static const _apiKey = 'AIzaSyDf7swKIZ5hSnMWL_SRrAYxT_4reWKsgTg';

  late final _model = GenerativeModel(
    model: 'gemini-2.0-flash',
    apiKey: _apiKey,
    generationConfig: GenerationConfig(
      temperature: 0.8,
      maxOutputTokens: 4096,
      responseMimeType: 'application/json',
    ),
  );

  /// Takes any user input and extracts a structured trip plan.
  Future<AiTripResult> generateTrip({
    required String userInput,
    bool isArabic = false,
  }) async {
    final lang = isArabic ? 'Arabic' : 'English';

    final prompt = '''
You are Rihla, a fun and adventurous AI travel planner.

The user says: "$userInput"

Extract and generate a complete trip plan. Respond ONLY with valid JSON (no markdown, no backticks) in this exact schema:

{
  "trip_title": "A catchy title for the trip in $lang",
  "trip_start_date": "YYYY-MM-DD",
  "trip_end_date": "YYYY-MM-DD",
  "locations": [
    {"name": "Place name", "lat": 13.7563, "lng": 100.5018, "transport_type": "flight", "is_overnight": true}
  ],
  "transportation_suggestions": [
    "Flight from Muscat to Bangkok – Search & book here: https://www.google.com/travel/flights?q=flights+from+Muscat+to+Bangkok+on+July+10",
    "Rent a car in Phuket – Search here: https://www.google.com/search?q=car+rental+Phuket+July+2025"
  ],
  "daily_itinerary": [
    "Day 1: Arrival and check-in. Explore ...",
    "Day 2: Morning visit to ... Afternoon ..."
  ],
  "daily_agenda": [
    {"day_index": 1, "date": "2025-07-10", "city": "Bangkok", "pois": [{"name": "Grand Palace", "description": "Historic temple complex", "lat": 13.75, "lng": 100.49, "search_query": "Grand Palace Bangkok"}, {"name": "Wat Pho", "description": "Temple of the Reclining Buddha", "search_query": "Wat Pho Bangkok"}]},
    {"day_index": 2, "date": "2025-07-11", "city": "Bangkok", "pois": [{"name": "Chatuchak Market", "search_query": "Chatuchak Market Bangkok"}]}
  ]
}

Rules:
- trip_start_date and trip_end_date: Infer from the user's message. If they say "July 10" or "March 15-22", set these. If no dates given, use today as start and infer end from number of days (e.g. 5-day trip = start today, end today+4). Always output YYYY-MM-DD.
- Include ALL locations mentioned or implied by the user, with real GPS coordinates.
- For each location, set "transport_type" to how the traveler ARRIVES at that stop: "flight", "drive", "train", or "ferry". Set "is_overnight" to true if they stay overnight there.
- IMPORTANT for transportation_suggestions: Provide Google Search/Travel links for flights and car rentals, not guessed prices.
- daily_itinerary: Keep as human-readable day-by-day summary (same as before).
- daily_agenda: REQUIRED. One object per day of the trip. For each day include: day_index (1-based), date (YYYY-MM-DD, same as trip dates), city (or area name), and pois: array of points of interest for that day. Each POI must have: name (required), description (optional), lat/lng (optional), search_query (required: short phrase for photo search, e.g. "Senso-ji Tokyo"). Extract every notable place, attraction, restaurant, or activity mentioned or implied for that day. If the user did not specify dates, use consecutive days from trip_start_date.
- If the user is vague, infer 3-5 days and popular activities. Make it practical and include local gems.
- All text values must be in $lang (but keep URLs and search_query in English for best photo results).
${isArabic ? '- Use Arabic for trip_title, daily_itinerary, descriptions, and city names; keep search_query in English.' : ''}
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text;
      if (text == null || text.isEmpty) {
        throw Exception('Empty response from Gemini');
      }

      // Parse JSON – strip any accidental markdown fences
      var cleaned = text.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
        cleaned = cleaned.replaceFirst(RegExp(r'\s*```$'), '');
      }

      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      return AiTripResult.fromJson(json);
    } catch (e) {
      debugPrint('AiService.generateTrip error: $e');
      rethrow;
    }
  }
}
