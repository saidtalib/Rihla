import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../models/trip.dart';
import '../../services/payment_service.dart';
import '../../services/trip_service.dart';
import '../tabs/map_tab.dart';
import '../tabs/expense_tab.dart';
import '../tabs/vault_tab.dart';
import '../widgets/settings_toggles.dart';

/// Trip Command Center with BottomNavigationBar:
/// Home (back) · Map · Expense · Vault
class TripDetailsScreen extends StatefulWidget {
  const TripDetailsScreen({super.key, required this.trip});
  final Trip trip;

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  late Trip _trip;
  int _currentTab = 1; // Start on Map tab (index 1)

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
  }

  void _onTabTapped(int index) {
    if (index == 0) {
      // Home tab → navigate back to main screen
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _currentTab = index);
  }

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
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: RihlaColors.jungleGreen.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(Icons.share_rounded, size: 48, color: RihlaColors.jungleGreen),
            const SizedBox(height: 16),
            Text(ar ? 'رمز الانضمام' : 'Join Code',
                style: TextStyle(fontFamily: fontFamily, fontSize: 20, fontWeight: FontWeight.w700, color: RihlaColors.jungleGreen)),
            const SizedBox(height: 12),
            Text(ar ? 'شارك هذا الرمز مع أصدقائك:' : 'Share this code with your friends:',
                style: TextStyle(fontFamily: fontFamily, fontSize: 14, color: RihlaColors.jungleGreenDark.withValues(alpha: 0.6)),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _trip.joinCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ar ? 'تم النسخ!' : 'Copied!'), backgroundColor: RihlaColors.jungleGreen),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: RihlaColors.jungleGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: RihlaColors.jungleGreen.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_trip.joinCode,
                        style: TextStyle(fontFamily: GoogleFonts.pangolin().fontFamily, fontSize: 32, fontWeight: FontWeight.w800, color: RihlaColors.sunsetOrange, letterSpacing: 6)),
                    const SizedBox(width: 12),
                    Icon(Icons.copy_rounded, color: RihlaColors.jungleGreen.withValues(alpha: 0.5)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: () => Navigator.pop(context), child: Text(ar ? 'تم' : 'Done')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentTab) {
      case 1:
        return MapTab(trip: _trip);
      case 2:
        return ExpenseTab(trip: _trip);
      case 3:
        return VaultTab(trip: _trip);
      default:
        return MapTab(trip: _trip);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);
    final ar = settings.isArabic;
    final dark = settings.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(_trip.title, overflow: TextOverflow.ellipsis),
        automaticallyImplyLeading: false, // no back arrow — use Home tab
        actions: [
          IconButton(
            icon: Icon(_trip.isPublic ? Icons.group_rounded : Icons.share_rounded),
            tooltip: ar ? 'مشاركة' : 'Share',
            onPressed: _onShare,
          ),
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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _buildBody(),
      ),

      // ── Bottom Navigation Bar ────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            currentIndex: _currentTab,
            onTap: _onTabTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: dark ? const Color(0xFF1E1E36) : Colors.white,
            selectedItemColor: RihlaColors.sunsetOrange,
            unselectedItemColor: dark
                ? RihlaColors.darkText.withValues(alpha: 0.5)
                : RihlaColors.jungleGreen.withValues(alpha: 0.55),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_rounded),
                label: ar ? 'الرئيسية' : 'Home',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.map_rounded),
                label: ar ? 'الخريطة' : 'Map',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.monetization_on_rounded),
                label: ar ? 'المصاريف' : 'Expense',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.folder_rounded),
                label: ar ? 'الخزنة' : 'Vault',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
