import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);
    final ar = settings.isArabic;
    final dark = settings.isDarkMode;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_rounded,
              size: 72, color: RihlaColors.sunsetOrange.withValues(alpha: 0.8)),
          const SizedBox(height: 16),
          Text(
            ar ? 'المصاريف' : 'Expenses',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: dark ? RihlaColors.saharaSand : RihlaColors.jungleGreen,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            ar ? 'تتبع وقسّم تكاليف الرحلة بسهولة.' : 'Track & split trip costs effortlessly.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
