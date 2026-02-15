import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_settings.dart';
import '../../models/trip.dart';
import '../../services/trip_service.dart';
import '../../ui/theme/app_theme.dart';
import '../widgets/ad_banner.dart';
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

    try {
      final trip = await TripService.instance.findByJoinCode(code);
      if (!mounted) return;

      if (trip == null) {
        setState(() {
          _loading = false;
          _error = ar
              ? 'لم يتم العثور على رحلة بهذا الرمز'
              : 'No trip found with this code';
        });
        return;
      }

      // Already a member — navigate directly
      if (TripService.instance.currentUserHasAccess(trip)) {
        _navigateToTrip(trip);
        return;
      }

      // Trip not shared yet
      if (!trip.isPublic) {
        setState(() {
          _loading = false;
          _error = ar
              ? 'هذه الرحلة لم تتم مشاركتها بعد'
              : 'This trip hasn\'t been shared yet';
        });
        return;
      }

      // Add user to trip members
      await TripService.instance.addPaidMember(trip.id);
      if (!mounted) return;
      final updated = await TripService.instance.getTrip(trip.id);
      if (!mounted) return;
      _navigateToTrip(updated ?? trip);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(ar ? 'الانضمام لرحلة' : 'Join a Trip'),
        actions: const [],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.group_add_rounded,
                            size: 40, color: cs.primary),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        ar ? 'أدخل رمز الانضمام' : 'Enter Join Code',
                        style: tt.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ar
                            ? 'اطلب الرمز من منظم الرحلة'
                            : 'Ask the trip organizer for the code',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      // Code input
                      TextField(
                        controller: _codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _join(),
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 8,
                          color: cs.primary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'ABC123',
                          counterText: '',
                          hintStyle: TextStyle(
                            fontSize: 28,
                            letterSpacing: 8,
                            color: cs.onSurface.withValues(alpha: 0.15),
                          ),
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: R.error.withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(R.radiusMd),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: R.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_error!,
                                    style: tt.bodySmall
                                        ?.copyWith(color: R.error)),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _join,
                          icon: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Icon(Icons.login_rounded),
                          label: Text(
                            ar ? 'انضم الآن' : 'Join Now',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
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
