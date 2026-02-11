import 'package:flutter/material.dart';

/// Provides app-wide settings (language, dark mode) to all descendants.
///
/// Usage: `AppSettings.of(context).isArabic`
class AppSettings extends InheritedWidget {
  const AppSettings({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.toggleLanguage,
    required this.toggleDarkMode,
    required super.child,
  });

  final bool isArabic;
  final bool isDarkMode;
  final VoidCallback toggleLanguage;
  final VoidCallback toggleDarkMode;

  static AppSettings of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppSettings>()!;
  }

  @override
  bool updateShouldNotify(AppSettings oldWidget) =>
      isArabic != oldWidget.isArabic || isDarkMode != oldWidget.isDarkMode;
}
