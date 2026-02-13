import 'package:flutter/material.dart';

// Re-export the new theme system for backward compatibility.
export '../ui/theme/app_theme.dart';

/// Legacy alias: map old Safari/Sahara/Orange to new Indigo/Slate palette.
class RihlaColors {
  RihlaColors._();
  static const Color jungleGreen = Color(0xFF4F46E5); // Indigo
  static const Color jungleGreenLight = Color(0xFF6366F1);
  static const Color jungleGreenDark = Color(0xFF3730A3);
  static const Color saharaSand = Color(0xFFF9FAFB); // Surface
  static const Color saharaSandDark = Color(0xFFF1F5F9);
  static const Color sunsetOrange = Color(0xFF4F46E5); // Indigo (primary CTA)
  static const Color sunsetOrangeLight = Color(0xFF6366F1);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF252540);
  static const Color darkText = Color(0xFFE8E8EE);
}
