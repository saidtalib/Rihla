import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/monetization_manager.dart';
import '../../core/theme.dart';

/// A reusable AdMob banner widget that loads & renders an adaptive banner.
/// On web it renders an empty placeholder (AdMob doesn't support web).
///
/// Drop it anywhere:
/// ```dart
/// const RihlaAdBanner()
/// ```
class RihlaAdBanner extends StatefulWidget {
  const RihlaAdBanner({super.key});

  @override
  State<RihlaAdBanner> createState() => _RihlaAdBannerState();
}

class _RihlaAdBannerState extends State<RihlaAdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!kIsWeb && _bannerAd == null) _loadAd();
  }

  Future<void> _loadAd() async {
    final width = MediaQuery.of(context).size.width.truncate();
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (size == null) return;

    final ad = BannerAd(
      adUnitId: AdIds.banner,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner failed to load: ${error.message}');
          ad.dispose();
        },
      ),
    );

    await ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !_isLoaded || _bannerAd == null) {
      // On web or while loading: subtle placeholder so layout doesn't jump.
      return Container(
        height: 60,
        alignment: Alignment.center,
        color: RihlaColors.saharaSand,
        child: Text(
          '· · ·',
          style: TextStyle(
            color: RihlaColors.jungleGreen.withValues(alpha: 0.2),
            fontSize: 18,
          ),
        ),
      );
    }

    return Container(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      alignment: Alignment.center,
      color: RihlaColors.saharaSand,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
