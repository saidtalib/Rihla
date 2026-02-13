import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ──────────────────────────────────────────────
//  Persisted settings data (loaded once at startup)
// ──────────────────────────────────────────────

/// Holds all user preferences. Loaded from SharedPreferences at app start,
/// and written back on every change.
class AppSettingsData {
  bool isArabic;
  ThemeMode themeMode;
  bool useMetric;
  bool useDDMMYYYY;
  bool notifChat;
  bool notifExpense;
  bool notifPlan;
  bool notifVault;
  bool permissionAsked;

  AppSettingsData({
    this.isArabic = false,
    this.themeMode = ThemeMode.system,
    this.useMetric = true,
    this.useDDMMYYYY = true,
    this.notifChat = true,
    this.notifExpense = true,
    this.notifPlan = true,
    this.notifVault = true,
    this.permissionAsked = false,
  });

  /// Load all preferences from disk. Call once before runApp().
  static Future<AppSettingsData> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettingsData(
      isArabic: prefs.getBool('isArabic') ?? false,
      themeMode: ThemeMode.values[prefs.getInt('themeMode') ?? 0],
      useMetric: prefs.getBool('useMetric') ?? true,
      useDDMMYYYY: prefs.getBool('useDDMMYYYY') ?? true,
      notifChat: prefs.getBool('notifChat') ?? true,
      notifExpense: prefs.getBool('notifExpense') ?? true,
      notifPlan: prefs.getBool('notifPlan') ?? true,
      notifVault: prefs.getBool('notifVault') ?? true,
      permissionAsked: prefs.getBool('permissionAsked') ?? false,
    );
  }

  /// Persist a single key.
  Future<void> _setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _setInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  // ── Setters that also persist ─────────────────

  Future<void> setArabic(bool v) async {
    isArabic = v;
    await _setBool('isArabic', v);
  }

  Future<void> setThemeMode(ThemeMode v) async {
    themeMode = v;
    await _setInt('themeMode', v.index);
  }

  Future<void> setUseMetric(bool v) async {
    useMetric = v;
    await _setBool('useMetric', v);
  }

  Future<void> setUseDDMMYYYY(bool v) async {
    useDDMMYYYY = v;
    await _setBool('useDDMMYYYY', v);
  }

  Future<void> setNotifChat(bool v) async {
    notifChat = v;
    await _setBool('notifChat', v);
  }

  Future<void> setNotifExpense(bool v) async {
    notifExpense = v;
    await _setBool('notifExpense', v);
  }

  Future<void> setNotifPlan(bool v) async {
    notifPlan = v;
    await _setBool('notifPlan', v);
  }

  Future<void> setNotifVault(bool v) async {
    notifVault = v;
    await _setBool('notifVault', v);
  }

  Future<void> setPermissionAsked(bool v) async {
    permissionAsked = v;
    await _setBool('permissionAsked', v);
  }

  /// Convenience: is dark based on ThemeMode (for places that need a bool).
  bool get isDarkMode => themeMode == ThemeMode.dark;
}

// ──────────────────────────────────────────────
//  InheritedWidget — provides settings to the tree
// ──────────────────────────────────────────────

/// Provides app-wide settings (language, theme, prefs) to all descendants.
///
/// Usage: `AppSettings.of(context).isArabic`
class AppSettings extends InheritedWidget {
  const AppSettings({
    super.key,
    required this.data,
    required this.onChanged,
    required super.child,
  });

  final AppSettingsData data;

  /// Callback to trigger a rebuild after any setting changes.
  final VoidCallback onChanged;

  // ── Convenience getters ─────────────────────

  bool get isArabic => data.isArabic;
  bool get isDarkMode => data.isDarkMode;
  ThemeMode get themeMode => data.themeMode;
  bool get useMetric => data.useMetric;
  bool get useDDMMYYYY => data.useDDMMYYYY;
  bool get notifChat => data.notifChat;
  bool get notifExpense => data.notifExpense;
  bool get notifPlan => data.notifPlan;
  bool get notifVault => data.notifVault;

  // ── Legacy callbacks (used by SettingsToggles) ──

  void toggleLanguage() {
    data.setArabic(!data.isArabic);
    onChanged();
  }

  void toggleDarkMode() {
    final next = data.themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    data.setThemeMode(next);
    onChanged();
  }

  static AppSettings of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppSettings>()!;
  }

  @override
  bool updateShouldNotify(AppSettings oldWidget) => true;
}
