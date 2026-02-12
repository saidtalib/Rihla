import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'core/app_settings.dart';
import 'core/monetization_manager.dart';
import 'services/auth_service.dart';
import 'services/payment_service.dart';
import 'ui/screens/confirm_profile_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/theme/app_theme.dart';
import 'ui/widgets/settings_toggles.dart';

// ──────────────────────────────────────────────
//  Entry point
// ──────────────────────────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase Core
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('[main] Firebase initialised ✓');
  } catch (e) {
    debugPrint('[main] Firebase init skipped: $e');
  }

  // 2. RevenueCat
  try {
    await PaymentService.instance.init();
  } catch (e) {
    debugPrint('[main] RevenueCat init skipped: $e');
  }

  // 3. AdMob
  if (!kIsWeb) {
    try {
      await MonetizationManager.instance.init();
      MonetizationManager.instance.loadInterstitial();
    } catch (e) {
      debugPrint('[main] AdMob init skipped: $e');
    }
  }

  runApp(const RihlaApp());
}

// ──────────────────────────────────────────────
//  Root Widget
// ──────────────────────────────────────────────
class RihlaApp extends StatefulWidget {
  const RihlaApp({super.key});

  @override
  State<RihlaApp> createState() => _RihlaAppState();
}

class _RihlaAppState extends State<RihlaApp> {
  bool _isArabic = false;
  bool _isDarkMode = false;

  void _toggleLanguage() => setState(() => _isArabic = !_isArabic);
  void _toggleDarkMode() => setState(() => _isDarkMode = !_isDarkMode);

  @override
  Widget build(BuildContext context) {
    return AppSettings(
      isArabic: _isArabic,
      isDarkMode: _isDarkMode,
      toggleLanguage: _toggleLanguage,
      toggleDarkMode: _toggleDarkMode,
      child: MaterialApp(
        title: 'Rihla',
        debugShowCheckedModeBanner: false,
        theme: buildRihlaTheme(isArabic: _isArabic, isDark: _isDarkMode),
        builder: (context, child) {
          return Directionality(
            textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: child!,
          );
        },
        home: const _AuthGate(),
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  Auth Gate — routes based on auth state
// ──────────────────────────────────────────────
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snap) {
        // Loading
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
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
//  Main Screen (AppBar + Home — no bottom nav)
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
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: Text('🌍', style: const TextStyle(fontSize: 26)),
          ),
        ),
        title: Text(
          'Rihla',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          const SettingsToggles(),
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
