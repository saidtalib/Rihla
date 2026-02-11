import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);
    final ar = settings.isArabic;
    final dark = settings.isDarkMode;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_rounded,
              size: 72, color: RihlaColors.sunsetOrange.withValues(alpha: 0.8)),
          const SizedBox(height: 16),
          Text(
            ar ? 'الدردشة الجماعية' : 'Group Chat',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: dark ? RihlaColors.saharaSand : RihlaColors.jungleGreen,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            ar ? 'نسّق مع فريق رحلتك.' : 'Coordinate with your travel crew.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
