import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ──────────────────────────────────────────────
//  Rihla Brand Palette
// ──────────────────────────────────────────────
class RihlaColors {
  RihlaColors._();

  static const Color jungleGreen = Color(0xFF2D5A27);
  static const Color saharaSand = Color(0xFFF4EBD0);
  static const Color sunsetOrange = Color(0xFFFF8C00);

  // Derived shades
  static const Color jungleGreenLight = Color(0xFF4A7A42);
  static const Color jungleGreenDark = Color(0xFF1B3A18);
  static const Color saharaSandDark = Color(0xFFE0D5B0);
  static const Color sunsetOrangeLight = Color(0xFFFFAB40);

  // Dark-mode specific
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF252540);
  static const Color darkText = Color(0xFFE8E8EE);
}

// ──────────────────────────────────────────────
//  Button Theme (bubbly, playful, 25 px radius)
// ──────────────────────────────────────────────
final _bubbleRadius = BorderRadius.circular(25);

ElevatedButtonThemeData _elevatedButtonTheme({required bool isDark}) =>
    ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: RihlaColors.sunsetOrange,
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: RihlaColors.sunsetOrange.withValues(alpha: 0.45),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: _bubbleRadius),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );

OutlinedButtonThemeData _outlinedButtonTheme({required bool isDark}) =>
    OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? RihlaColors.saharaSand : RihlaColors.jungleGreen,
        side: BorderSide(
          color: isDark ? RihlaColors.saharaSand : RihlaColors.jungleGreen,
          width: 1.5,
        ),
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: _bubbleRadius),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );

TextButtonThemeData _textButtonTheme({required bool isDark}) =>
    TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: RihlaColors.sunsetOrange,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: _bubbleRadius),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );

// ──────────────────────────────────────────────
//  Text Theme builder (language-aware)
// ──────────────────────────────────────────────
TextTheme _buildTextTheme(TextTheme base, {required bool isArabic}) {
  final fontFamily =
      isArabic ? GoogleFonts.cairo().fontFamily : GoogleFonts.pangolin().fontFamily;

  return base.copyWith(
    displayLarge: base.displayLarge?.copyWith(fontFamily: fontFamily),
    displayMedium: base.displayMedium?.copyWith(fontFamily: fontFamily),
    displaySmall: base.displaySmall?.copyWith(fontFamily: fontFamily),
    headlineLarge: base.headlineLarge?.copyWith(fontFamily: fontFamily),
    headlineMedium: base.headlineMedium?.copyWith(fontFamily: fontFamily),
    headlineSmall: base.headlineSmall?.copyWith(fontFamily: fontFamily),
    titleLarge: base.titleLarge?.copyWith(fontFamily: fontFamily, fontWeight: FontWeight.w700),
    titleMedium: base.titleMedium?.copyWith(fontFamily: fontFamily, fontWeight: FontWeight.w600),
    titleSmall: base.titleSmall?.copyWith(fontFamily: fontFamily, fontWeight: FontWeight.w600),
    bodyLarge: base.bodyLarge?.copyWith(fontFamily: fontFamily),
    bodyMedium: base.bodyMedium?.copyWith(fontFamily: fontFamily),
    bodySmall: base.bodySmall?.copyWith(fontFamily: fontFamily),
    labelLarge: base.labelLarge?.copyWith(fontFamily: fontFamily, fontWeight: FontWeight.w600),
    labelMedium: base.labelMedium?.copyWith(fontFamily: fontFamily),
    labelSmall: base.labelSmall?.copyWith(fontFamily: fontFamily),
  );
}

// ──────────────────────────────────────────────
//  Public ThemeData builder
// ──────────────────────────────────────────────
ThemeData buildRihlaTheme({bool isArabic = false, bool isDark = false}) {
  final brightness = isDark ? Brightness.dark : Brightness.light;

  final colorScheme = isDark
      ? ColorScheme.fromSeed(
          seedColor: RihlaColors.jungleGreen,
          brightness: Brightness.dark,
          primary: RihlaColors.jungleGreenLight,
          secondary: RihlaColors.saharaSandDark,
          tertiary: RihlaColors.sunsetOrange,
          surface: RihlaColors.darkSurface,
          onPrimary: Colors.white,
          onSecondary: RihlaColors.darkText,
          onSurface: RihlaColors.darkText,
        )
      : ColorScheme.fromSeed(
          seedColor: RihlaColors.jungleGreen,
          brightness: Brightness.light,
          primary: RihlaColors.jungleGreen,
          secondary: RihlaColors.saharaSand,
          tertiary: RihlaColors.sunsetOrange,
          surface: RihlaColors.saharaSand,
          onPrimary: Colors.white,
          onSecondary: RihlaColors.jungleGreenDark,
          onSurface: RihlaColors.jungleGreenDark,
        );

  final scaffoldBg = isDark ? RihlaColors.darkSurface : RihlaColors.saharaSand;
  final cardBg = isDark ? RihlaColors.darkCard : Colors.white;
  final inputFill = isDark ? RihlaColors.darkCard : Colors.white;
  final inputHintColor = isDark
      ? RihlaColors.darkText.withValues(alpha: 0.45)
      : RihlaColors.jungleGreenDark.withValues(alpha: 0.4);
  final navBarBg = isDark ? const Color(0xFF1E1E36) : Colors.white;

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    brightness: brightness,
    scaffoldBackgroundColor: scaffoldBg,
  );

  final textTheme = _buildTextTheme(base.textTheme, isArabic: isArabic);

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: RihlaColors.jungleGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: Colors.white,
        fontSize: 22,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: navBarBg,
      selectedItemColor: RihlaColors.sunsetOrange,
      unselectedItemColor: isDark
          ? RihlaColors.darkText.withValues(alpha: 0.5)
          : RihlaColors.jungleGreen.withValues(alpha: 0.55),
      type: BottomNavigationBarType.fixed,
      elevation: 12,
      selectedLabelStyle: TextStyle(
        fontFamily: isArabic
            ? GoogleFonts.cairo().fontFamily
            : GoogleFonts.pangolin().fontFamily,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: isArabic
            ? GoogleFonts.cairo().fontFamily
            : GoogleFonts.pangolin().fontFamily,
        fontWeight: FontWeight.w500,
        fontSize: 11,
      ),
    ),
    elevatedButtonTheme: _elevatedButtonTheme(isDark: isDark),
    outlinedButtonTheme: _outlinedButtonTheme(isDark: isDark),
    textButtonTheme: _textButtonTheme(isDark: isDark),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: RihlaColors.sunsetOrange,
      foregroundColor: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: _bubbleRadius),
    ),
    cardTheme: CardThemeData(
      color: cardBg,
      elevation: isDark ? 1 : 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      hintStyle: TextStyle(color: inputHintColor),
      border: OutlineInputBorder(
        borderRadius: _bubbleRadius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: _bubbleRadius,
        borderSide: BorderSide(
          color: isDark
              ? RihlaColors.darkText.withValues(alpha: 0.15)
              : RihlaColors.jungleGreen.withValues(alpha: 0.2),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: _bubbleRadius,
        borderSide: const BorderSide(color: RihlaColors.sunsetOrange, width: 2),
      ),
    ),
    // Explicit text selection / cursor theme for TextFields
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: RihlaColors.sunsetOrange,
      selectionColor: RihlaColors.sunsetOrange.withValues(alpha: 0.3),
      selectionHandleColor: RihlaColors.sunsetOrange,
    ),
  );
}
