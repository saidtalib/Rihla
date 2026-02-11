import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ──────────────────────────────────────────────
//  AdMob identifiers  (STM / Rihla)
//
//  When production IDs are not yet provided we
//  fall back to the official Google test IDs so
//  the build never shows real ads by accident.
// ──────────────────────────────────────────────
class AdIds {
  AdIds._();

  // ── App-level ID (AndroidManifest.xml) ─────
  // Set via meta-data in the manifest; kept here for reference.
  static const String appId = 'YOUR_ADMOB_APP_ID';

  // ── Banner ─────────────────────────────────
  static String get banner {
    if (kDebugMode) return _testBanner;
    return 'YOUR_ADMOB_BANNER_ID';
  }

  // ── Interstitial ──────────────────────────
  static String get interstitial {
    if (kDebugMode) return _testInterstitial;
    return 'YOUR_ADMOB_INTERSTITIAL_ID';
  }

  // Google's official test ad unit IDs.
  // Use the Android IDs on Android, iOS IDs everywhere else (desktop/iOS).
  // On web this class is never reached (guarded in main.dart & ad_banner.dart).
  static String get _testBanner {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'ca-app-pub-3940256099942544/6300978111';
      default:
        return 'ca-app-pub-3940256099942544/2934735716';
    }
  }

  static String get _testInterstitial {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'ca-app-pub-3940256099942544/1033173712';
      default:
        return 'ca-app-pub-3940256099942544/4411468910';
    }
  }
}

// ──────────────────────────────────────────────
//  Monetization Manager  (singleton)
// ──────────────────────────────────────────────
class MonetizationManager {
  MonetizationManager._();
  static final MonetizationManager instance = MonetizationManager._();

  InterstitialAd? _interstitialAd;
  bool _interstitialReady = false;

  /// Initialise the Mobile Ads SDK.  Call once from main().
  Future<void> init() async {
    await MobileAds.instance.initialize();
  }

  // ── Interstitial ──────────────────────────

  /// Pre-load an interstitial so it's ready to show instantly.
  void loadInterstitial() {
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialReady = true;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialReady = false;
              loadInterstitial(); // pre-load the next one
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialReady = false;
              loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial failed to load: ${error.message}');
          _interstitialReady = false;
        },
      ),
    );
  }

  /// Show the interstitial if one is ready; returns whether it was shown.
  bool showInterstitialIfReady() {
    if (_interstitialReady && _interstitialAd != null) {
      _interstitialAd!.show();
      return true;
    }
    return false;
  }
}
