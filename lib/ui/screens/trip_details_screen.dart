import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_settings.dart';
import '../../models/trip.dart';
import '../../services/trip_service.dart';
import '../../ui/theme/app_theme.dart';
import '../tabs/home_tab.dart';
import '../tabs/map_tab.dart';
import '../tabs/pack_tab.dart';
import '../tabs/vault_tab.dart';
import '../widgets/settings_toggles.dart';
import 'kitty_screen.dart';

/// Trip Dashboard with TabBar: Home · Map · The Pack · The Kitty · Vault
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
    _tabCtrl = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _onTripUpdated(Trip updated) {
    setState(() => _trip = updated);
  }

  bool get _isAdmin => TripService.instance.currentUserIsAdmin(_trip);

  // ── Admin-only share ──────────────────────────
  Future<void> _onShare() async {
    final ar = AppSettings.of(context).isArabic;
    final code = _trip.joinCode;
    final link = 'https://rihla.app/join/$code';

    // Ensure trip is marked public
    if (!_trip.isPublic) {
      await TripService.instance.markPublic(_trip.id);
      setState(() => _trip = _trip.copyWith(isPublic: true));
    }

    if (!mounted) return;

    // Show share sheet + bottom sheet with code
    _showShareSheet(ar, code, link);
  }

  void _showShareSheet(bool ar, String code, String link) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(Icons.share_rounded, size: 40, color: cs.primary),
            const SizedBox(height: 12),
            Text(
              ar ? 'شارك الرحلة' : 'Share Trip',
              style: tt.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              ar
                  ? 'شارك هذا الرابط مع أصدقائك:'
                  : 'Share this link with your friends:',
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),

            // Code display
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ar ? 'تم النسخ!' : 'Copied!'),
                    backgroundColor: R.success,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(R.radiusMd),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      code,
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.copy_rounded,
                        color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Share button (native)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Share.share(
                    ar
                        ? 'انضم لرحلتي على Rihla! الرمز: $code\n$link'
                        : 'Join my trip on Rihla! Code: $code\n$link',
                  );
                },
                icon: const Icon(Icons.send_rounded),
                label: Text(ar ? 'مشاركة الرابط' : 'Share Link'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(ar ? 'تم' : 'Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ar = AppSettings.of(context).isArabic;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _trip.title,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Share icon — ONLY visible to admin
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: ar ? 'مشاركة' : 'Share',
              onPressed: _onShare,
            ),
          const SettingsToggles(),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
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
              icon: const Icon(Icons.monetization_on_rounded,
                  size: 20, color: Color(0xFFFFD700)),
              text: ar ? 'الجطية' : 'The Kitty',
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
          KittyScreen(trip: _trip, onTripUpdated: _onTripUpdated),
          VaultTab(trip: _trip),
        ],
      ),
    );
  }
}
