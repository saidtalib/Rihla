import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Structured result returned by the AI trip planner.
class AiTripResult {
  final String tripTitle;
  final List<AiLocation> locations;
  final List<String> transportSuggestions;
  final List<String> dailyItinerary;

  const AiTripResult({
    required this.tripTitle,
    required this.locations,
    required this.transportSuggestions,
    required this.dailyItinerary,
  });

  factory AiTripResult.fromJson(Map<String, dynamic> json) {
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
      maxOutputTokens: 2048,
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
  ]
}

Rules:
- Include ALL locations mentioned or implied by the user, with real GPS coordinates.
- For each location, set "transport_type" to how the traveler ARRIVES at that stop: "flight", "drive", "train", or "ferry". For the very first location use the most logical mode from the origin.
- Set "is_overnight" to true if the traveler stays overnight at that location (hotel/camp), false if it's just a day visit or transit.
- IMPORTANT for transportation_suggestions: Do NOT guess or approximate prices. Instead, for each flight or car rental, provide a direct Google Search/Travel link so the user can check real prices. Format: "Flight from [City A] to [City B] – Search & book: https://www.google.com/travel/flights?q=flights+from+[CityA]+to+[CityB]+on+[Date]" and for car rentals: "Rent a car in [City] – Search: https://www.google.com/search?q=car+rental+[City]+[Month]+[Year]". Replace spaces in URLs with +.
- Generate a detailed daily itinerary covering the entire trip duration.
- If the user is vague, infer reasonable defaults (3-5 days, popular activities).
- Make it practical, exciting, and include local hidden gems.
- All text values must be in $lang (but keep URLs in English).
${isArabic ? '- Use Arabic for all text values including day labels like "اليوم 1:" but keep URLs in English.' : ''}
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
