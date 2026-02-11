import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../models/trip.dart';
import '../../services/trip_service.dart';
import '../widgets/settings_toggles.dart';
import 'trip_details_screen.dart';

/// Shows all trips the user has created or paid to join — always free.
class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  late Future<List<Trip>> _tripsFuture;

  @override
  void initState() {
    super.initState();
    _tripsFuture = TripService.instance.myTrips();
  }

  void _refresh() {
    setState(() => _tripsFuture = TripService.instance.myTrips());
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
        title: Text(ar ? 'رحلاتي' : 'My Trips'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _refresh),
          const SettingsToggles(),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [RihlaColors.jungleGreenDark, RihlaColors.jungleGreen],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Trip>>(
        future: _tripsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: RihlaColors.jungleGreen));
          }
          if (snap.hasError) {
            debugPrint('[TripHistory] FutureBuilder error: ${snap.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      ar ? 'حدث خطأ' : 'Something went wrong',
                      style: TextStyle(fontFamily: fontFamily, fontSize: 18, color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snap.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: fontFamily, fontSize: 12, color: Colors.red.shade300),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: Text(ar ? 'إعادة المحاولة' : 'Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final trips = snap.data ?? [];
          if (trips.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 72, color: headingColor.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text(
                    ar ? 'لا توجد رحلات بعد' : 'No trips yet',
                    style: TextStyle(fontFamily: fontFamily, fontSize: 20, fontWeight: FontWeight.w600, color: headingColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ar ? 'أنشئ أو انضم لرحلة لتظهر هنا' : 'Create or join a trip to see it here',
                    style: TextStyle(fontFamily: fontFamily, fontSize: 14, color: headingColor.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trips.length,
            itemBuilder: (context, i) {
              final trip = trips[i];

              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: RihlaColors.jungleGreen.withValues(alpha: 0.1),
                    child: Icon(Icons.landscape_rounded, color: RihlaColors.jungleGreen),
                  ),
                  title: Text(
                    trip.title,
                    style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, color: headingColor),
                  ),
                  subtitle: Row(
                    children: [
                      Icon(Icons.people_rounded, size: 14, color: headingColor.withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Text(
                        '${trip.paidMembers.length} ${ar ? "أعضاء" : "members"}',
                        style: TextStyle(fontSize: 12, color: headingColor.withValues(alpha: 0.5)),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        trip.isPublic ? Icons.public_rounded : Icons.lock_rounded,
                        size: 14,
                        color: trip.isPublic ? RihlaColors.jungleGreen : RihlaColors.sunsetOrange,
                      ),
                    ],
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: headingColor.withValues(alpha: 0.5)),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TripDetailsScreen(trip: trip),
                      ),
                    ).then((_) => _refresh());
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
