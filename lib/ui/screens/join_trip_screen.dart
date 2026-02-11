import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../models/trip.dart';
import '../../services/payment_service.dart';
import '../../services/trip_service.dart';
import '../widgets/ad_banner.dart';
import '../widgets/settings_toggles.dart';
import 'trip_details_screen.dart';

/// Screen where members enter a join code to access a trip.
class JoinTripScreen extends StatefulWidget {
  const JoinTripScreen({super.key});

  @override
  State<JoinTripScreen> createState() => _JoinTripScreenState();
}

class _JoinTripScreenState extends State<JoinTripScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _join() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;

    final ar = AppSettings.of(context).isArabic;

    setState(() {
      _loading = true;
      _error = null;
    });

    final trip = await TripService.instance.findByJoinCode(code);
    if (!mounted) return;

    if (trip == null) {
      setState(() {
        _loading = false;
        _error = ar ? 'لم يتم العثور على رحلة بهذا الرمز' : 'No trip found with this code';
      });
      return;
    }

    if (TripService.instance.currentUserHasAccess(trip)) {
      _navigateToTrip(trip);
      return;
    }

    if (!trip.isPublic) {
      setState(() {
        _loading = false;
        _error = ar ? 'هذه الرحلة لم تتم مشاركتها بعد' : 'This trip hasn\'t been shared yet';
      });
      return;
    }

    setState(() => _loading = false);
    final paid = await showTripPaywall(
      context,
      isArabic: ar,
      type: PaywallType.join,
    );
    if (!mounted) return;

    if (paid) {
      setState(() => _loading = true);
      await TripService.instance.addPaidMember(trip.id);
      if (!mounted) return;
      final updated = await TripService.instance.getTrip(trip.id);
      if (!mounted) return;
      _navigateToTrip(updated ?? trip);
    }
  }

  void _navigateToTrip(Trip trip) {
    setState(() => _loading = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TripDetailsScreen(trip: trip),
      ),
    );
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);
    final ar = settings.isArabic;
    final dark = settings.isDarkMode;
    final fontFamily =
        ar ? GoogleFonts.cairo().fontFamily : GoogleFonts.pangolin().fontFamily;
    final headingColor = dark ? RihlaColors.saharaSand : RihlaColors.jungleGreen;

    return Scaffold(
      appBar: AppBar(
        title: Text(ar ? 'الانضمام لرحلة' : 'Join a Trip'),
        actions: const [SettingsToggles()],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [RihlaColors.jungleGreenDark, RihlaColors.jungleGreen],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 88, height: 88,
                      decoration: BoxDecoration(
                        color: RihlaColors.sunsetOrange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(child: Text('🎫', style: TextStyle(fontSize: 44))),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      ar ? 'أدخل رمز الانضمام' : 'Enter Join Code',
                      style: TextStyle(fontFamily: fontFamily, fontSize: 24, fontWeight: FontWeight.w700, color: headingColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ar ? 'اطلب الرمز من منظم الرحلة' : 'Ask the trip organizer for the code',
                      style: TextStyle(fontFamily: fontFamily, fontSize: 14, color: headingColor.withValues(alpha: 0.6)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // ── Code input ──────────────────
                    TextField(
                      controller: _codeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.go,
                      style: TextStyle(
                        fontFamily: GoogleFonts.pangolin().fontFamily,
                        fontSize: 28, fontWeight: FontWeight.w800,
                        letterSpacing: 8,
                        color: RihlaColors.sunsetOrange,
                      ),
                      decoration: InputDecoration(
                        hintText: 'ABC123',
                        counterText: '',
                        hintStyle: TextStyle(
                          fontSize: 28, letterSpacing: 8,
                          color: headingColor.withValues(alpha: 0.2),
                        ),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 14)),
                    ],

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity, height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _join,
                        icon: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.login_rounded),
                        label: Text(
                          ar ? 'انضم الآن' : 'Join Now',
                          style: TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const RihlaAdBanner(),
        ],
      ),
    );
  }
}
