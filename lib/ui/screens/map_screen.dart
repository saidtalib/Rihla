import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../widgets/ad_banner.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);
    final ar = settings.isArabic;
    final dark = settings.isDarkMode;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.map_rounded,
                  size: 72,
                  color: RihlaColors.jungleGreen.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  ar ? 'الخريطة والاستكشاف' : 'Map & Explore',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: dark ? RihlaColors.saharaSand : RihlaColors.jungleGreen,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  ar
                      ? 'اكتشف الوجهات على الخريطة.'
                      : 'Discover destinations on the map.',
                  style: Theme.of(context).textTheme.bodyMedium,
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
