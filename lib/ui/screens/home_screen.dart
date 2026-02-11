import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../widgets/ad_banner.dart';
import 'create_trip_screen.dart';
import 'join_trip_screen.dart';
import 'trip_history_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);
    final ar = settings.isArabic;
    final dark = settings.isDarkMode;
    final fontFamily =
        ar ? GoogleFonts.cairo().fontFamily : GoogleFonts.pangolin().fontFamily;

    final textColor = dark ? RihlaColors.darkText : RihlaColors.jungleGreenDark;

    return Column(
      children: [
        // ── Main content (expands) ──────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                // ── Hero ─────────────────────────
                Icon(
                  Icons.landscape_rounded,
                  size: 80,
                  color: RihlaColors.jungleGreen.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 20),
                Text(
                  ar ? 'مرحبًا بك في رحلة!' : 'Welcome to Rihla!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: dark ? RihlaColors.saharaSand : RihlaColors.jungleGreen,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  ar
                      ? 'خطط، شارك، واستمتع بمغامرتك القادمة.'
                      : 'Plan, share & enjoy your next adventure.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: textColor.withValues(alpha: 0.65),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                // ── Action cards ─────────────────
                _ActionCard(
                  icon: Icons.auto_awesome_rounded,
                  title: ar ? 'إنشاء رحلة' : 'Create Trip',
                  subtitle: ar ? 'مجاني – خطط بالذكاء الاصطناعي' : 'Free – AI-powered planning',
                  color: RihlaColors.jungleGreen,
                  fontFamily: fontFamily!,
                  isDark: dark,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateTripScreen()),
                  ),
                ),
                const SizedBox(height: 14),
                _ActionCard(
                  icon: Icons.login_rounded,
                  title: ar ? 'الانضمام لرحلة' : 'Join a Trip',
                  subtitle: ar ? 'أدخل رمز الانضمام' : 'Enter a join code',
                  color: RihlaColors.sunsetOrange,
                  fontFamily: fontFamily,
                  isDark: dark,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const JoinTripScreen()),
                  ),
                ),
                const SizedBox(height: 14),
                _ActionCard(
                  icon: Icons.history_rounded,
                  title: ar ? 'رحلاتي' : 'My Trips',
                  subtitle: ar ? 'الرحلات السابقة والحالية' : 'Past & current trips',
                  color: RihlaColors.jungleGreenLight,
                  fontFamily: fontFamily,
                  isDark: dark,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TripHistoryScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Ad banner pinned to bottom ──────────
        const RihlaAdBanner(),
      ],
    );
  }
}

// ── Reusable action card ──────────────────────

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.fontFamily,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String fontFamily;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? RihlaColors.darkCard : Colors.white;
    final titleColor = isDark ? RihlaColors.darkText : RihlaColors.jungleGreenDark;
    final subColor = isDark
        ? RihlaColors.darkText.withValues(alpha: 0.55)
        : RihlaColors.jungleGreenDark.withValues(alpha: 0.55);

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(18),
      elevation: isDark ? 1 : 3,
      shadowColor: color.withValues(alpha: 0.18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(fontFamily: fontFamily, fontSize: 17, fontWeight: FontWeight.w700, color: titleColor)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(fontFamily: fontFamily, fontSize: 13, color: subColor)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
