import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../services/ai_service.dart';
import '../../services/trip_service.dart';
import '../widgets/ad_banner.dart';
import 'trip_details_screen.dart';

/// Free step: Describe your trip in any way, Gemini AI extracts everything.
class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _inputCtrl = TextEditingController();

  bool _generating = false;
  bool _saving = false;
  String? _error;
  AiTripResult? _result;

  // ── Ask Gemini ─────────────────────────────
  Future<void> _generate() async {
    if (_inputCtrl.text.trim().isEmpty) return;
    setState(() {
      _generating = true;
      _error = null;
      _result = null;
    });

    final ar = AppSettings.of(context).isArabic;

    try {
      final result = await AiService.instance.generateTrip(
        userInput: _inputCtrl.text.trim(),
        isArabic: ar,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _generating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = ar
            ? 'فشل إنشاء الخطة. تحقق من اتصالك بالإنترنت.'
            : 'Failed to generate plan. Check your connection.';
      });
    }
  }

  // ── Save to Firestore ──────────────────────
  Future<void> _save() async {
    if (_result == null) return;
    final ar = AppSettings.of(context).isArabic;
    setState(() => _saving = true);

    debugPrint('[CreateTripScreen] Save button pressed');
    debugPrint('[CreateTripScreen] AI result title: ${_result!.tripTitle}');

    try {
      debugPrint('[CreateTripScreen] Calling TripService.createFromAiResult...');
      final trip = await TripService.instance.createFromAiResult(
        _result!,
        description: _inputCtrl.text.trim(),
      );
      debugPrint('[CreateTripScreen] Trip saved! ID: ${trip.id}');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ar
                ? 'تم بنجاح! مرحبًا بك في رحلتك 🏕️'
                : 'Success! Welcome to your Safari 🏕️',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: RihlaColors.jungleGreen,
          duration: const Duration(seconds: 2),
        ),
      );

      // Navigate to TripDetailsScreen immediately
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      debugPrint('[CreateTripScreen] Navigating to TripDetailsScreen...');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => TripDetailsScreen(trip: trip)),
      );
    } catch (e) {
      debugPrint('[CreateTripScreen] Save FAILED: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ar
                ? 'خطأ في الحفظ: $e'
                : 'Save failed: $e',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);
    final ar = settings.isArabic;
    final dark = settings.isDarkMode;
    final fontFamily =
        ar ? GoogleFonts.cairo().fontFamily : GoogleFonts.pangolin().fontFamily;
    final labelColor = dark ? RihlaColors.saharaSand : RihlaColors.jungleGreen;
    final inputStyle = TextStyle(
      color: dark ? RihlaColors.darkText : RihlaColors.jungleGreenDark,
      fontSize: 15,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(ar ? 'إنشاء رحلة' : 'Create Trip'),
        actions: const [],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [RihlaColors.jungleGreenDark, RihlaColors.jungleGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Prompt label ─────────────
                  Text(
                    ar ? 'صف رحلتك بأي طريقة' : 'Describe your trip in any way',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ar
                        ? 'جملة قصيرة أو قصة طويلة – الذكاء الاصطناعي يفهمك!'
                        : 'A short sentence or a long story — AI gets it!',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 13,
                      color: labelColor.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Big text input ───────────
                  TextField(
                    controller: _inputCtrl,
                    style: inputStyle,
                    maxLines: 6,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: ar
                          ? 'مثال: خطط لرحلة عائلية من مسقط إلى بانكوك يوم 10 يوليو. نريد 3 أيام لاستكشاف المعابد والطعام في بانكوك، ثم رحلة قصيرة إلى بوكيت لمدة 4 ليالٍ، ثم الطيران إلى شيانغ ماي ليومين لزيارة محميات الأفيال...'
                          : "e.g., plan a family trip starting on July 10 from Muscat to Bangkok. We'd like to spend three days exploring the temples and street food in Bangkok before taking a short flight to Phuket for four nights then fly to Chiang Mai for two days to experience elephant sanctuaries ...",
                      hintMaxLines: 6,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Generate button ──────────
                  if (_result == null)
                    ElevatedButton.icon(
                      onPressed: _generating ? null : _generate,
                      icon: _generating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome_rounded),
                      label: Text(
                        _generating
                            ? (ar
                                ? 'جاري استكشاف مسارك...'
                                : 'Scouting your route...')
                            : (ar
                                ? 'إنشاء الخطة بالذكاء الاصطناعي'
                                : 'Generate AI Plan'),
                      ),
                    ),

                  // ── Error ────────────────────
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  // ── AI Result preview ────────
                  if (_result != null) ...[
                    const SizedBox(height: 16),
                    _SectionHeader(
                      icon: Icons.flight_takeoff_rounded,
                      title: _result!.tripTitle,
                      color: labelColor,
                      fontFamily: fontFamily!,
                    ),
                    const SizedBox(height: 12),

                    // Locations
                    if (_result!.locations.isNotEmpty) ...[
                      _SectionHeader(
                        icon: Icons.place_rounded,
                        title: ar ? 'المواقع' : 'Locations',
                        color: RihlaColors.sunsetOrange,
                        fontFamily: fontFamily,
                        fontSize: 16,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _result!.locations
                            .map((l) => Chip(
                                  avatar: const Icon(Icons.location_on,
                                      size: 16,
                                      color: RihlaColors.sunsetOrange),
                                  label: Text(l.name,
                                      style: TextStyle(
                                          fontFamily: fontFamily,
                                          fontSize: 13)),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Transport
                    if (_result!.transportSuggestions.isNotEmpty) ...[
                      _SectionHeader(
                        icon: Icons.directions_car_rounded,
                        title: ar ? 'المواصلات' : 'Transport',
                        color: RihlaColors.jungleGreenLight,
                        fontFamily: fontFamily,
                        fontSize: 16,
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(
                          _result!.transportSuggestions.length, (i) {
                        final suggestion = _result!.transportSuggestions[i];
                        final urlMatch = RegExp(r'https?://\S+').firstMatch(suggestion);
                        final hasLink = urlMatch != null;

                        return Card(
                          child: ListTile(
                            leading: Icon(
                              hasLink ? Icons.flight_takeoff_rounded : Icons.directions_bus_rounded,
                              color: RihlaColors.jungleGreenLight,
                            ),
                            title: Text(
                              suggestion.replaceAll(RegExp(r'https?://\S+'), '').trim(),
                              style: TextStyle(fontFamily: fontFamily, fontSize: 13),
                            ),
                            subtitle: hasLink
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      ar ? '🔗 اضغط للبحث عن الأسعار' : '🔗 Tap to search prices',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: RihlaColors.sunsetOrange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                : null,
                            trailing: hasLink
                                ? Icon(Icons.open_in_new_rounded, size: 18, color: RihlaColors.sunsetOrange)
                                : null,
                            onTap: hasLink
                                ? () => launchUrl(Uri.parse(urlMatch.group(0)!), mode: LaunchMode.externalApplication)
                                : null,
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // Daily itinerary
                    _SectionHeader(
                      icon: Icons.calendar_today_rounded,
                      title: ar ? 'خطة الرحلة اليومية' : 'Daily Itinerary',
                      color: labelColor,
                      fontFamily: fontFamily,
                      fontSize: 16,
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(_result!.dailyItinerary.length, (i) {
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: RihlaColors.sunsetOrange
                                .withValues(alpha: 0.15),
                            child: Text('${i + 1}',
                                style: TextStyle(
                                    color: RihlaColors.sunsetOrange,
                                    fontWeight: FontWeight.w700)),
                          ),
                          title: Text(
                            _result!.dailyItinerary[i],
                            style: TextStyle(
                                fontFamily: fontFamily, fontSize: 13),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),

                    // Save / Regenerate
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(ar ? 'حفظ الرحلة' : 'Save Trip'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _generating
                          ? null
                          : () => setState(() => _result = null),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(ar ? 'إعادة الإنشاء' : 'Regenerate'),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Ad banner ──────────────────────
          const RihlaAdBanner(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
    required this.fontFamily,
    this.fontSize = 20,
  });

  final IconData icon;
  final String title;
  final Color color;
  final String fontFamily;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: fontSize + 2),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
