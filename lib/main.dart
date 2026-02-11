import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'core/app_settings.dart';
import 'core/theme.dart';
import 'core/monetization_manager.dart';
import 'services/payment_service.dart';
import 'ui/screens/home_screen.dart';
import 'ui/widgets/settings_toggles.dart';

// ──────────────────────────────────────────────
//  Entry point
// ──────────────────────────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Firebase Core
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('[main] Firebase initialised ✓');
  } catch (e) {
    debugPrint('[main] Firebase init skipped: $e');
  }

  // 2. Anonymous sign-in (gives us a real UID for Firestore)
  try {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
      debugPrint('[main] Signed in anonymously: ${auth.currentUser?.uid}');
    } else {
      debugPrint('[main] Already signed in: ${auth.currentUser?.uid}');
    }
  } catch (e) {
    debugPrint('[main] Anonymous auth skipped: $e');
  }

  // 3. RevenueCat
  try {
    await PaymentService.instance.init();
  } catch (e) {
    debugPrint('[main] RevenueCat init skipped: $e');
  }

  // 4. AdMob
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
        home: const MainScreen(),
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  Main Screen  (AppBar + Home — no bottom nav)
// ──────────────────────────────────────────────
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: Text('\ud83c\udf0d', style: const TextStyle(fontSize: 26)),
          ),
        ),
        title: Text(
          'Rihla',
          style: GoogleFonts.pangolin(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        actions: const [SettingsToggles()],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [RihlaColors.jungleGreenDark, RihlaColors.jungleGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: const HomeScreen(),
    );
  }
}
