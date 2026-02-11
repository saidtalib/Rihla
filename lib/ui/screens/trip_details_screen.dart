import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../models/trip.dart';
import '../../services/payment_service.dart';
import '../../services/trip_service.dart';
import '../tabs/home_tab.dart';
import '../tabs/map_tab.dart';
import '../tabs/pack_tab.dart';
import '../tabs/vault_tab.dart';
import '../widgets/settings_toggles.dart';

/// Trip Dashboard with TabBar: Home · Map · The Pack · Vault
class TripDetailsScreen extends StatefulWidget {
  const TripDetailsScreen({super.key, required this.trip});
  final Trip trip;

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen>
    with SingleTickerProviderStateMixin {
  late Trip _trip;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _onTripUpdated(Trip updated) {
    setState(() => _trip = updated);
  }

  // ── Share / Join code ─────────────────────────
  Future<void> _onShare() async {
    final ar = AppSettings.of(context).isArabic;

    if (_trip.isPublic) {
      _showJoinCode(ar);
      return;
    }

    final paid = await showTripPaywall(
      context,
      isArabic: ar,
      type: PaywallType.share,
    );
    if (!mounted) return;

    if (paid) {
      await TripService.instance.markPublic(_trip.id);
      setState(() => _trip = _trip.copyWith(isPublic: true));
      _showJoinCode(ar);
    }
  }

  void _showJoinCode(bool ar) {
    final fontFamily =
        ar ? GoogleFonts.cairo().fontFamily : GoogleFonts.pangolin().fontFamily;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: RihlaColors.saharaSand,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: RihlaColors.jungleGreen.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(Icons.share_rounded,
                size: 48, color: RihlaColors.jungleGreen),
            const SizedBox(height: 16),
            Text(ar ? 'رمز الانضمام' : 'Join Code',
                style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: RihlaColors.jungleGreen)),
            const SizedBox(height: 12),
            Text(
                ar
                    ? 'شارك هذا الرمز مع أصدقائك:'
                    : 'Share this code with your friends:',
                style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 14,
                    color:
                        RihlaColors.jungleGreenDark.withValues(alpha: 0.6)),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _trip.joinCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(ar ? 'تم النسخ!' : 'Copied!'),
                      backgroundColor: RihlaColors.jungleGreen),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: RihlaColors.jungleGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color:
                          RihlaColors.jungleGreen.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_trip.joinCode,
                        style: TextStyle(
                            fontFamily: GoogleFonts.pangolin().fontFamily,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: RihlaColors.sunsetOrange,
                            letterSpacing: 6)),
                    const SizedBox(width: 12),
                    Icon(Icons.copy_rounded,
                        color:
                            RihlaColors.jungleGreen.withValues(alpha: 0.5)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(ar ? 'تم' : 'Done')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);
    final ar = settings.isArabic;
    final fontFamily =
        ar ? GoogleFonts.cairo().fontFamily : GoogleFonts.pangolin().fontFamily;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _trip.title,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: fontFamily),
        ),
        actions: [
          IconButton(
            icon: Icon(
                _trip.isPublic ? Icons.group_rounded : Icons.share_rounded),
            tooltip: ar ? 'مشاركة' : 'Share',
            onPressed: _onShare,
          ),
          const SettingsToggles(),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [RihlaColors.jungleGreenDark, RihlaColors.jungleGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: RihlaColors.sunsetOrange,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
          ),
          tabs: [
            Tab(
              icon: const Icon(Icons.home_rounded, size: 20),
              text: ar ? 'الرئيسية' : 'Home',
            ),
            Tab(
              icon: const Icon(Icons.map_rounded, size: 20),
              text: ar ? 'الخريطة' : 'Map',
            ),
            Tab(
              icon: const Icon(Icons.groups_rounded, size: 20),
              text: ar ? 'العزوة' : 'The Pack',
            ),
            Tab(
              icon: const Icon(Icons.folder_rounded, size: 20),
              text: ar ? 'الخزنة' : 'Vault',
            ),
          ],
        ),
      ),

      body: TabBarView(
        controller: _tabCtrl,
        children: [
          HomeTab(trip: _trip, onTripUpdated: _onTripUpdated),
          MapTab(trip: _trip),
          PackTab(trip: _trip, onTripUpdated: _onTripUpdated),
          VaultTab(trip: _trip),
        ],
      ),
    );
  }
}
