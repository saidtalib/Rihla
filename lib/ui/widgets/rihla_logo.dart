import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bilingual logo for Rihla: icon + "Rihla" (Poppins) | "رحلة" (Tajawal) + optional tagline.
/// Uses Indigo Blue (#4F46E5) for the icon and divider.
class RihlaLogo extends StatelessWidget {
  const RihlaLogo({
    super.key,
    this.tagline,
  });

  /// Optional tagline; if null, shows default English tagline.
  final String? tagline;

  @override
  Widget build(BuildContext context) {
    const Color indigoBlue = Color(0xFF4F46E5);
    const Color slateDark = Color(0xFF111827);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.explore_rounded,
          size: 64,
          color: indigoBlue,
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
                color: slateDark,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 24,
              width: 2,
              color: indigoBlue.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 12),
            Text(
              'رحلة',
              style: GoogleFonts.tajawal(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: slateDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          tagline ?? 'Plan trips with your crew',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF6B7280),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
