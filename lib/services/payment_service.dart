import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../core/theme.dart';

// ──────────────────────────────────────────────
//  RevenueCat identifiers  (STM / Rihla)
// ──────────────────────────────────────────────
const String _revenueCatApiKey = 'YOUR_REVENUECAT_SDK_KEY';
const String _entitlementId = 'premium_trip';
const String _packageId = 'trip_credit';

// ──────────────────────────────────────────────
//  Payment Service  (singleton)
// ──────────────────────────────────────────────
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  bool _initialized = false;

  /// Call once from main() after WidgetsFlutterBinding.
  Future<void> init() async {
    if (_initialized) return;
    await Purchases.configure(
      PurchasesConfiguration(_revenueCatApiKey),
    );
    _initialized = true;
  }

  /// Returns `true` when the user owns the "premium_trip" entitlement.
  Future<bool> hasPremiumTrip() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.all[_entitlementId]?.isActive ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Attempt to purchase the `trip_credit` package.
  /// Returns `true` on success.
  Future<bool> purchaseTripCredit() async {
    try {
      final offerings = await Purchases.getOfferings();
      final offering = offerings.current;
      if (offering == null) return false;

      final package = offering.availablePackages.firstWhere(
        (p) => p.identifier == _packageId,
        orElse: () => offering.availablePackages.first,
      );

      final result = await Purchases.purchasePackage(package);
      return result.entitlements.all[_entitlementId]?.isActive ?? false;
    } on PurchasesErrorCode {
      return false;
    } catch (_) {
      return false;
    }
  }
}

// ══════════════════════════════════════════════
//  Paywall Modals  (Safari-themed, bilingual)
// ══════════════════════════════════════════════

/// Paywall variant used throughout the app.
enum PaywallType {
  /// Admin wants to share a trip with their group.
  share,

  /// Member wants to join an existing trip.
  join,
}

/// Show a Safari-themed $1 paywall bottom sheet.
/// Returns `true` when the purchase succeeds.
Future<bool> showTripPaywall(
  BuildContext context, {
  required bool isArabic,
  PaywallType type = PaywallType.share,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PaywallSheet(isArabic: isArabic, type: type),
  ).then((v) => v ?? false);
}

// ── Localised copy per type ──────────────────

class _PaywallCopy {
  final String emoji;
  final String titleEn;
  final String titleAr;
  final String descEn;
  final String descAr;
  final String subtitleEn;
  final String subtitleAr;

  const _PaywallCopy({
    required this.emoji,
    required this.titleEn,
    required this.titleAr,
    required this.descEn,
    required this.descAr,
    required this.subtitleEn,
    required this.subtitleAr,
  });
}

const _copies = <PaywallType, _PaywallCopy>{
  PaywallType.share: _PaywallCopy(
    emoji: '🔗',
    titleEn: 'Share Your Trip!',
    titleAr: 'شارك رحلتك!',
    descEn: 'Pay \$1 to share this trip with your group',
    descAr: 'ادفع 1 دولار لمشاركة هذه الرحلة مع مجموعتك',
    subtitleEn: 'Your group will be able to join, chat & split costs.',
    subtitleAr: 'سيتمكن فريقك من الانضمام والدردشة وتقسيم التكاليف.',
  ),
  PaywallType.join: _PaywallCopy(
    emoji: '🏕️',
    titleEn: 'Join This Trip!',
    titleAr: 'انضم لهذه الرحلة!',
    descEn: 'Pay \$1 to join this group trip',
    descAr: 'ادفع 1 دولار للانضمام إلى هذه الرحلة الجماعية',
    subtitleEn: 'Get full access to the itinerary, group chat & expenses.',
    subtitleAr: 'احصل على وصول كامل لخطة الرحلة والدردشة والمصاريف.',
  ),
};

// ── Sheet widget ─────────────────────────────

class _PaywallSheet extends StatefulWidget {
  const _PaywallSheet({required this.isArabic, required this.type});
  final bool isArabic;
  final PaywallType type;

  @override
  State<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<_PaywallSheet> {
  bool _loading = false;

  Future<void> _buy() async {
    setState(() => _loading = true);
    final success = await PaymentService.instance.purchaseTripCredit();
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pop(success);
  }

  @override
  Widget build(BuildContext context) {
    final ar = widget.isArabic;
    final copy = _copies[widget.type]!;
    final fontFamily =
        ar ? GoogleFonts.cairo().fontFamily : GoogleFonts.pangolin().fontFamily;

    return Container(
      decoration: const BoxDecoration(
        color: RihlaColors.saharaSand,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: RihlaColors.jungleGreen.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // illustration
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              color: RihlaColors.jungleGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(copy.emoji, style: const TextStyle(fontSize: 44))),
          ),
          const SizedBox(height: 20),

          // title
          Text(
            ar ? copy.titleAr : copy.titleEn,
            style: TextStyle(
              fontFamily: fontFamily, fontSize: 24,
              fontWeight: FontWeight.w700, color: RihlaColors.jungleGreen,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // description
          Text(
            ar ? copy.descAr : copy.descEn,
            style: TextStyle(
              fontFamily: fontFamily, fontSize: 17, fontWeight: FontWeight.w500,
              color: RihlaColors.jungleGreenDark.withValues(alpha: 0.75),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            ar ? copy.subtitleAr : copy.subtitleEn,
            style: TextStyle(
              fontFamily: fontFamily, fontSize: 14,
              color: RihlaColors.jungleGreenDark.withValues(alpha: 0.55),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // price badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: RihlaColors.sunsetOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Text(
              '\$1.00',
              style: TextStyle(
                fontFamily: fontFamily, fontSize: 28,
                fontWeight: FontWeight.w800, color: RihlaColors.sunsetOrange,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // CTA button
          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _buy,
              style: ElevatedButton.styleFrom(
                backgroundColor: RihlaColors.jungleGreen,
                foregroundColor: Colors.white,
                elevation: 6,
                shadowColor: RihlaColors.jungleGreen.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(
                      ar ? 'ادفع الآن' : 'Pay Now',
                      style: TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // cancel
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              ar ? 'ليس الآن' : 'Not now',
              style: TextStyle(
                fontFamily: fontFamily, fontSize: 14,
                color: RihlaColors.jungleGreen.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
