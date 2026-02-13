import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_settings.dart';
import '../theme/app_theme.dart';

/// Bilingual logo for Rihla: icon, English + Arabic name, tagline.
/// Uses Poppins (EN), Tajawal (AR), and Indigo accent.
class RihlaLogo extends StatelessWidget {
  const RihlaLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final ar = AppSettings.of(context).isArabic;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.explore_rounded,
          size: 64,
          color: R.indigo,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Rihla',
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: R.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 24,
              width: 2,
              color: R.indigo.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 12),
            Text(
              'رحلة',
              style: GoogleFonts.tajawal(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: R.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          ar ? 'خطط رحلتك مع أصدقائك' : 'Plan trips with your crew',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: R.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
