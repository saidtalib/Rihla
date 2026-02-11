import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_settings.dart';
import '../../core/theme.dart';

/// A compact row of two toggles: Dark/Light mode and EN/AR language.
/// Designed to sit in any AppBar's `actions` list.
class SettingsToggles extends StatelessWidget {
  const SettingsToggles({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Dark / Light toggle ──────────────
          _MiniToggle(
            icon: settings.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            onTap: settings.toggleDarkMode,
            tooltip: settings.isDarkMode ? 'Light mode' : 'Dark mode',
          ),
          const SizedBox(width: 6),
          // ── EN / AR toggle ──────────────────
          _LanguagePill(
            isArabic: settings.isArabic,
            onTap: settings.toggleLanguage,
          ),
        ],
      ),
    );
  }
}

// ── Small icon button for dark/light ─────────

class _MiniToggle extends StatelessWidget {
  const _MiniToggle({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

// ── EN / AR pill toggle ──────────────────────

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({required this.isArabic, required this.onTap});

  final bool isArabic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Chip(label: 'EN', active: !isArabic),
            const SizedBox(width: 2),
            _Chip(label: 'ع', active: isArabic, isArabicFont: true),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, this.isArabicFont = false});

  final String label;
  final bool active;
  final bool isArabicFont;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? RihlaColors.sunsetOrange : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        boxShadow: active
            ? [BoxShadow(color: RihlaColors.sunsetOrange.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))]
            : [],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: isArabicFont ? GoogleFonts.cairo().fontFamily : GoogleFonts.pangolin().fontFamily,
          color: active ? Colors.white : Colors.white.withValues(alpha: 0.65),
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }
}
