import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rihla/core/theme.dart';

/// A premium-looking EN / AR toggle button.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({
    super.key,
    required this.isArabic,
    required this.onToggle,
  });

  final bool isArabic;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Chip(label: 'EN', active: !isArabic),
            const SizedBox(width: 2),
            _Chip(label: 'ع', active: isArabic, isArabicLabel: true),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    this.isArabicLabel = false,
  });

  final String label;
  final bool active;
  final bool isArabicLabel;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? RihlaColors.sunsetOrange : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        boxShadow: active
            ? [
                BoxShadow(
                  color: RihlaColors.sunsetOrange.withValues(alpha: 0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: isArabicLabel
              ? GoogleFonts.cairo().fontFamily
              : GoogleFonts.pangolin().fontFamily,
          color: active ? Colors.white : Colors.white.withValues(alpha: 0.7),
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          fontSize: 14,
        ),
      ),
    );
  }
}
