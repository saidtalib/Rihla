import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'core/app_settings.dart';
import 'core/monetization_manager.dart';
import 'services/auth_service.dart';
import 'services/crash_log_service.dart';
import 'services/payment_service.dart';
import 'ui/screens/confirm_profile_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/theme/app_theme.dart';

// ──────────────────────────────────────────────
//  Entry point — show UI immediately, then init in background (avoids blank white screen).
// ──────────────────────────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capture Flutter framework errors (safe to call before dotenv)
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    CrashLogService.instance.logError(
      details.exception,
      details.stack,
    );
  };

  // Show a loading UI immediately so the app never stays on a blank white screen
  runApp(const _SplashRoot());
}

/// Root that shows loading first, then the real app after init (or an error screen).
class _SplashRoot extends StatefulWidget {
  const _SplashRoot();

  @override
  State<_SplashRoot> createState() => _SplashRootState();
}

class _SplashRootState extends State<_SplashRoot> {
  Widget? _app;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    runZonedGuarded(() async {
      try {
        // 1. Env (optional — app works with empty keys)
        try {
          await dotenv.load(fileName: 'assets/env.default');
        } catch (e) {
          debugPrint('[main] dotenv load skipped: $e');
        }

        // 2. Firebase Core — skip on iOS when config is still placeholder (avoids native crash in simulator)
        final firebaseOptions = DefaultFirebaseOptions.currentPlatform;
        final isIosPlaceholder = !kIsWeb &&
            defaultTargetPlatform == TargetPlatform.iOS &&
            (firebaseOptions.appId == 'YOUR-APP-ID' ||
                firebaseOptions.projectId == 'YOUR-PROJECT-ID');
        if (!isIosPlaceholder) {
          try {
            await Firebase.initializeApp(options: firebaseOptions);
            FirebaseFirestore.instance.settings = const Settings(
              persistenceEnabled: true,
              cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
            );
          } catch (e) {
            debugPrint('[main] Firebase init skipped: $e');
            CrashLogService.instance.logError(e, StackTrace.current);
          }
        } else {
          debugPrint(
              '[main] Firebase init skipped (iOS placeholder config). Run: flutterfire configure');
        }

        // 3. Settings (required for RihlaApp)
        AppSettingsData settingsData;
        try {
          settingsData = await AppSettingsData.load();
        } catch (e) {
          debugPrint('[main] AppSettings load fallback: $e');
          settingsData = AppSettingsData();
        }

        // 4. RevenueCat
        try {
          await PaymentService.instance.init();
        } catch (e) {
          debugPrint('[main] RevenueCat init skipped: $e');
        }

        // 5. AdMob
        if (!kIsWeb) {
          try {
            await MonetizationManager.instance.init();
            MonetizationManager.instance.loadInterstitial();
          } catch (e) {
            debugPrint('[main] AdMob init skipped: $e');
          }
        }

        if (!mounted) return;
        setState(() {
          _app = RihlaApp(settingsData: settingsData);
          _error = null;
        });
      } catch (e, st) {
        CrashLogService.instance.logError(e, st);
        if (mounted) {
          setState(() {
            _error = e.toString();
            _app = null;
          });
        }
      }
    }, (error, stackTrace) {
      CrashLogService.instance.logError(error, stackTrace);
      if (mounted) {
        setState(() {
          _error = error.toString();
          _app = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_app != null) return _app!;
    if (_error != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Something went wrong', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(_error!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      );
    }
    // Loading — visible so never blank white
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5), brightness: Brightness.light)),
      darkTheme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5), brightness: Brightness.dark)),
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Loading…', style: TextStyle(color: Colors.grey[700], fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  Root Widget
// ──────────────────────────────────────────────
class RihlaApp extends StatefulWidget {
  const RihlaApp({super.key, required this.settingsData});
  final AppSettingsData settingsData;

  @override
  State<RihlaApp> createState() => _RihlaAppState();
}

class _RihlaAppState extends State<RihlaApp> {
  late AppSettingsData _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settingsData;
  }

  void _onSettingsChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return AppSettings(
      data: _settings,
      onChanged: _onSettingsChanged,
      child: MaterialApp(
        title: 'Rihla',
        debugShowCheckedModeBanner: false,
        theme: buildRihlaTheme(isArabic: _settings.isArabic, isDark: false),
        darkTheme: buildRihlaTheme(isArabic: _settings.isArabic, isDark: true),
        themeMode: _settings.themeMode,
        builder: (context, child) {
          return Directionality(
            textDirection:
                _settings.isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: child!,
          );
        },
        home: const _PermissionGate(),
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  Permission Gate — one-time location dialog
// ──────────────────────────────────────────────
class _PermissionGate extends StatefulWidget {
  const _PermissionGate();

  @override
  State<_PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<_PermissionGate> {
  bool _checked = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      // Timeout so we never hang on a blank screen (e.g. if Geolocator blocks on iOS)
      _checkPermissions().then((_) {}).catchError((_) {
        if (mounted) setState(() => _checked = true);
      });
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted && !_checked) {
          setState(() => _checked = true);
        }
      });
    }
  }

  Future<void> _checkPermissions() async {
    // Skip on web — the browser handles permissions natively
    if (kIsWeb) {
      setState(() => _checked = true);
      return;
    }

    final settings = AppSettings.of(context).data;

    // Only ask once per install
    if (settings.permissionAsked) {
      setState(() => _checked = true);
      return;
    }

    final permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      await settings.setPermissionAsked(true);
      if (mounted) setState(() => _checked = true);
      return;
    }

    if (!mounted) return;

    // Show the "Why we need this" dialog
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final ar = AppSettings.of(ctx).isArabic;
        return AlertDialog(
          icon: const Icon(Icons.explore_rounded, size: 40),
          title: Text(ar ? 'خدمة الموقع' : 'Location Access'),
          content: Text(
            ar
                ? 'يستخدم تطبيق رحلة موقعك لعرض موضعك على خرائط الرحلات وتوفير التنقل.'
                : 'Rihla uses your location to show your position on trip maps and provide navigation directions.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ar ? 'لاحقاً' : 'Maybe Later'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ar ? 'السماح' : 'Allow'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final newPerm = await Geolocator.requestPermission();
      if (newPerm == LocationPermission.deniedForever && mounted) {
        await showDialog(
          context: context,
          builder: (ctx) {
            final ar = AppSettings.of(ctx).isArabic;
            return AlertDialog(
              title: Text(ar ? 'الإذن مرفوض' : 'Permission Denied'),
              content: Text(
                ar
                    ? 'تم رفض إذن الموقع نهائياً. يمكنك تغييره من إعدادات الجهاز.'
                    : 'Location permission has been permanently denied. You can change this from your device Settings.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Geolocator.openAppSettings();
                    Navigator.pop(ctx);
                  },
                  child: Text(ar ? 'فتح الإعدادات' : 'Open Settings'),
                ),
              ],
            );
          },
        );
      }
    }

    await settings.setPermissionAsked(true);
    if (mounted) setState(() => _checked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      final cs = Theme.of(context).colorScheme;
      return Scaffold(
        backgroundColor: cs.surface,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: cs.primary),
              const SizedBox(height: 16),
              Text(
                'Loading…',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const _AuthGate();
  }
}

// ──────────────────────────────────────────────
//  Auth Gate — routes based on auth state (with timeout so we never hang blank)
// ──────────────────────────────────────────────
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    // If Firebase auth state doesn't emit within 10s, show login so screen isn't blank
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && !_timedOut) {
        setState(() => _timedOut = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snap) {
        // If we've been waiting too long, show login so screen isn't blank
        if (snap.connectionState == ConnectionState.waiting && _timedOut) {
          return const LoginScreen();
        }
        // Loading — use visible colors so screen is never blank
        if (snap.connectionState == ConnectionState.waiting) {
          final cs = Theme.of(context).colorScheme;
          return Scaffold(
            backgroundColor: cs.surface,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: cs.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Loading…',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final user = snap.data;

        // Not signed in → Login
        if (user == null) {
          return const LoginScreen();
        }

        // Signed in but profile incomplete → Onboarding
        if (!AuthService.instance.isProfileComplete) {
          return const ConfirmProfileScreen();
        }

        // Signed in and profile complete → Main app
        // Sync profile on entry
        AuthService.instance.syncUserToFirestore();
        return const MainScreen();
      },
    );
  }
}

// ──────────────────────────────────────────────
//  Main Screen (Clean AppBar — no globe, no toggles)
// ──────────────────────────────────────────────
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.of(context);
    final ar = settings.isArabic;
    final cs = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Rihla',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: false,
        actions: [
          // Settings icon
          IconButton(
            icon: const Icon(Icons.settings_rounded, size: 22),
            tooltip: ar ? 'الإعدادات' : 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          // Profile avatar / sign out
          PopupMenuButton<String>(
            offset: const Offset(0, 48),
            onSelected: (val) {
              if (val == 'signout') {
                AuthService.instance.signOut();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  user?.displayName ?? user?.email ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded, size: 18, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(ar ? 'تسجيل خروج' : 'Sign Out',
                        style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: cs.surfaceContainerHighest,
                backgroundImage: (user?.photoURL != null &&
                        user!.photoURL!.isNotEmpty)
                    ? NetworkImage(user.photoURL!)
                    : null,
                child: (user?.photoURL == null || user!.photoURL!.isEmpty)
                    ? Icon(Icons.person_rounded,
                        size: 18, color: cs.onSurfaceVariant)
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: const HomeScreen(),
    );
  }
}
