import 'package:flutter/material.dart';

// Re-export the new theme system for backward compatibility.
export '../ui/theme/app_theme.dart';

/// Legacy alias for files that import RihlaColors.
class RihlaColors {
  RihlaColors._();
  static const Color jungleGreen = Color(0xFF2D5A27);
  static const Color jungleGreenLight = Color(0xFF4A7A42);
  static const Color jungleGreenDark = Color(0xFF1B3A18);
  static const Color saharaSand = Color(0xFFF4EBD0);
  static const Color saharaSandDark = Color(0xFFE0D5B0);
  static const Color sunsetOrange = Color(0xFFFF8C00);
  static const Color sunsetOrangeLight = Color(0xFFFFAB40);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF252540);
  static const Color darkText = Color(0xFFE8E8EE);
}
