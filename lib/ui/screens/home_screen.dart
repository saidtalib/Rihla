import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../ui/theme/app_theme.dart';
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                // Hero
                Icon(Icons.landscape_rounded,
                    size: 72, color: cs.primary.withValues(alpha: 0.6)),
                const SizedBox(height: 20),
                Text(
                  ar ? 'مرحبًا بك في رحلة!' : 'Welcome to Rihla!',
                  style: tt.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  ar
                      ? 'خطط، شارك، واستمتع بمغامرتك القادمة.'
                      : 'Plan, share & enjoy your next adventure.',
                  style: tt.bodyLarge?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                _ActionCard(
                  icon: Icons.auto_awesome_rounded,
                  title: ar ? 'إنشاء رحلة' : 'Create Trip',
                  subtitle: ar
                      ? 'مجاني – خطط بالذكاء الاصطناعي'
                      : 'Free – AI-powered planning',
                  color: cs.primary,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const CreateTripScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  icon: Icons.login_rounded,
                  title: ar ? 'الانضمام لرحلة' : 'Join a Trip',
                  subtitle: ar ? 'أدخل رمز الانضمام' : 'Enter a join code',
                  color: R.warning,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const JoinTripScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  icon: Icons.history_rounded,
                  title: ar ? 'رحلاتي' : 'My Trips',
                  subtitle: ar
                      ? 'الرحلات السابقة والحالية'
                      : 'Past & current trips',
                  color: R.success,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const TripHistoryScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
        const RihlaAdBanner(),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(R.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(R.radiusMd),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5),
                        )),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: cs.onSurface.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}
