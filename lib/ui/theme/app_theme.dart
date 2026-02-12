import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ──────────────────────────────────────────────
//  Rihla Design Tokens (Wanderlog-inspired)
// ──────────────────────────────────────────────
class R {
  R._();

  // Primary accent — Indigo Blue
  static const Color indigo = Color(0xFF4F46E5);
  static const Color indigoLight = Color(0xFF6366F1);
  static const Color indigoDark = Color(0xFF3730A3);

  // Neutrals — Slate
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate50 = Color(0xFFF8FAFC);

  // Surfaces
  static const Color white = Colors.white;
  static const Color background = Color(0xFFFAFAFC);
  static const Color surface = Colors.white;
  static const Color surfaceDark = Color(0xFF111827);
  static const Color cardDark = Color(0xFF1F2937);

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Legacy safari colors (for backward compatibility in tabs)
  static const Color jungleGreen = Color(0xFF2D5A27);
  static const Color saharaSand = Color(0xFFF4EBD0);
  static const Color sunsetOrange = Color(0xFFFF8C00);
  static const Color jungleGreenDark = Color(0xFF1B3A18);
  static const Color jungleGreenLight = Color(0xFF4A7A42);
  static const Color saharaSandDark = Color(0xFFE0D5B0);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF252540);
  static const Color darkText = Color(0xFFE8E8EE);
  static const Color sunsetOrangeLight = Color(0xFFFFAB40);

  // Radius
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
}

// ──────────────────────────────────────────────
//  Text Theme (language-aware)
// ──────────────────────────────────────────────
TextTheme _buildTextTheme(TextTheme base, {required bool isArabic}) {
  final fontFamily = isArabic
      ? GoogleFonts.cairo().fontFamily
      : GoogleFonts.inter().fontFamily;

  return base.copyWith(
    displayLarge: base.displayLarge?.copyWith(fontFamily: fontFamily, fontWeight: FontWeight.w800),
    displayMedium: base.displayMedium?.copyWith(fontFamily: fontFamily, fontWeight: FontWeight.w700),
    displaySmall: base.displaySmall?.copyWith(fontFamily: fontFamily, fontWeight: FontWeight.w700),
    headlineLarge: base.headlineLarge?.copyWith(fontFamily: fontFamily, fontWeight: FontWeight.w700),
    headlineMedium: base.headlineMedium?.copyWith(fontFamily: fontFamily, fontWeight: FontWeight.w600),
    headlineSmall: base.headlineSmall?.copyWith(fontFamily: fontFamily, fontWeight: FontWeight.w600),
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
//  Light Theme
// ──────────────────────────────────────────────
ThemeData buildRihlaLightTheme({bool isArabic = false}) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: R.indigo,
    brightness: Brightness.light,
    primary: R.indigo,
    onPrimary: Colors.white,
    secondary: R.slate600,
    onSecondary: Colors.white,
    tertiary: R.warning,
    surface: R.white,
    onSurface: R.slate900,
    error: R.error,
    onError: Colors.white,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    brightness: Brightness.light,
    scaffoldBackgroundColor: R.background,
  );

  final textTheme = _buildTextTheme(base.textTheme, isArabic: isArabic);

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: R.white,
      foregroundColor: R.slate900,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: R.slate900,
        fontSize: 20,
      ),
      iconTheme: const IconThemeData(color: R.slate700),
    ),
    cardTheme: CardThemeData(
      color: R.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(R.radiusLg),
        side: BorderSide(color: R.slate200),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: R.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(R.radiusMd),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: R.indigo,
        side: const BorderSide(color: R.slate300),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(R.radiusMd),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: R.indigo,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(R.radiusMd),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: R.indigo,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(R.radiusLg),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: R.slate50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: R.slate400),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.radiusMd),
        borderSide: BorderSide(color: R.slate300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.radiusMd),
        borderSide: BorderSide(color: R.slate200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.radiusMd),
        borderSide: const BorderSide(color: R.indigo, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.radiusMd),
        borderSide: const BorderSide(color: R.error),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: R.indigo,
      selectionColor: R.indigo.withValues(alpha: 0.2),
      selectionHandleColor: R.indigo,
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE5E7EB),
      thickness: 1,
      space: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: R.slate100,
      selectedColor: R.indigo,
      labelStyle: textTheme.labelMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(R.radiusSm),
      ),
      side: BorderSide(color: R.slate200),
    ),
    tabBarTheme: TabBarThemeData(
      indicatorColor: R.indigo,
      labelColor: R.indigo,
      unselectedLabelColor: R.slate500,
      indicatorSize: TabBarIndicatorSize.label,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: R.white,
      selectedItemColor: R.indigo,
      unselectedItemColor: R.slate400,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(R.radiusMd),
      ),
    ),
  );
}

// ──────────────────────────────────────────────
//  Dark Theme
// ──────────────────────────────────────────────
ThemeData buildRihlaDarkTheme({bool isArabic = false}) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: R.indigo,
    brightness: Brightness.dark,
    primary: R.indigoLight,
    onPrimary: Colors.white,
    secondary: R.slate400,
    onSecondary: R.slate900,
    tertiary: R.warning,
    surface: R.surfaceDark,
    onSurface: const Color(0xFFE5E7EB),
    error: R.error,
    onError: Colors.white,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: R.surfaceDark,
  );

  final textTheme = _buildTextTheme(base.textTheme, isArabic: isArabic);

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: R.surfaceDark,
      foregroundColor: const Color(0xFFF3F4F6),
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: const Color(0xFFF3F4F6),
        fontSize: 20,
      ),
    ),
    cardTheme: CardThemeData(
      color: R.cardDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(R.radiusLg),
        side: BorderSide(color: R.slate700),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: R.indigoLight,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(R.radiusMd),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: R.indigoLight,
        side: BorderSide(color: R.slate600),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(R.radiusMd),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: R.indigoLight,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(R.radiusMd),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: R.indigoLight,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(R.radiusLg),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: R.cardDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: R.slate500),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.radiusMd),
        borderSide: BorderSide(color: R.slate600),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.radiusMd),
        borderSide: BorderSide(color: R.slate700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.radiusMd),
        borderSide: const BorderSide(color: R.indigoLight, width: 2),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: R.indigoLight,
      selectionColor: R.indigoLight.withValues(alpha: 0.3),
      selectionHandleColor: R.indigoLight,
    ),
    dividerTheme: DividerThemeData(
      color: R.slate700,
      thickness: 1,
      space: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: R.cardDark,
      selectedColor: R.indigoLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(R.radiusSm),
      ),
      side: BorderSide(color: R.slate600),
    ),
    tabBarTheme: TabBarThemeData(
      indicatorColor: R.indigoLight,
      labelColor: R.indigoLight,
      unselectedLabelColor: R.slate500,
      indicatorSize: TabBarIndicatorSize.label,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: R.surfaceDark,
      selectedItemColor: R.indigoLight,
      unselectedItemColor: R.slate500,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(R.radiusMd),
      ),
    ),
  );
}

/// Public builder that delegates to light/dark.
ThemeData buildRihlaTheme({bool isArabic = false, bool isDark = false}) {
  return isDark
      ? buildRihlaDarkTheme(isArabic: isArabic)
      : buildRihlaLightTheme(isArabic: isArabic);
}
