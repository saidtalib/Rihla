import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_settings.dart';

/// A compact row of two toggles: Dark/Light mode and EN/AR language.
/// Designed to sit in any AppBar's `actions` list.
class SettingsToggles extends StatelessWidget {
  const SettingsToggles({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniToggle(
            icon: settings.isDarkMode
                ? Icons.dark_mode_rounded
                : Icons.light_mode_rounded,
            onTap: settings.toggleDarkMode,
            tooltip: settings.isDarkMode ? 'Light mode' : 'Dark mode',
          ),
          const SizedBox(width: 4),
          _LanguagePill(
            isArabic: settings.isArabic,
            onTap: settings.toggleLanguage,
          ),
        ],
      ),
    );
  }
}

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
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, size: 18, color: cs.onSurface.withValues(alpha: 0.7)),
        ),
      ),
    );
  }
}

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({required this.isArabic, required this.onTap});

  final bool isArabic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(25),
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
  const _Chip(
      {required this.label, required this.active, this.isArabicFont = false});

  final String label;
  final bool active;
  final bool isArabicFont;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? cs.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: isArabicFont
              ? GoogleFonts.cairo().fontFamily
              : GoogleFonts.inter().fontFamily,
          color: active ? Colors.white : cs.onSurface.withValues(alpha: 0.5),
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}
