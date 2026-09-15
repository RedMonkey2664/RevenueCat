import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'purchases_service.dart';

/// RevenueCat's public SDK keys, one per store, supplied at build time:
///
///     flutter run --dart-define-from-file=config/revenuecat.json
///
/// (see `config/revenuecat.example.json`). These are RevenueCat's *public*
/// app-specific keys — designed to ship inside the app — but they are still
/// kept out of the repository so each environment chooses its own.
///
/// With no key for the current platform the app runs exactly as before, on
/// [StoreNotConnectedService].
abstract final class RevenueCatKeys {
  static const String apple = String.fromEnvironment('RC_APPLE_KEY');
  static const String google = String.fromEnvironment('RC_GOOGLE_KEY');
  static const String web = String.fromEnvironment('RC_WEB_KEY');

  /// RevenueCat's Test Store key. When set it wins on every platform, so the
  /// whole purchase flow can be exercised before any store is set up.
  /// Development only — never ship a build made with it.
  static const String test = String.fromEnvironment('RC_TEST_KEY');

  /// The entitlement every Pro gate checks (MONETIZATION.md).
  static const String entitlement = 'pro';

  /// The key for the platform this build is running on, or null.
  static String? current() {
    if (test.isNotEmpty) return test;
    final String key = kIsWeb
        ? web
        : switch (defaultTargetPlatform) {
            TargetPlatform.iOS || TargetPlatform.macOS => apple,
            TargetPlatform.android => google,
            _ => '',
          };
    return key.isEmpty ? null : key;
  }
}

/// The real store, through RevenueCat (MONETIZATION.md, Phase 8).
///
/// Maps RevenueCat's current offering onto the paywall's two plans — the
/// offering's *annual* package is YEARLY and its *monthly* package is
/// MONTHLY — and reads Pro from the `pro` entitlement. Prices are the store's
/// own localised strings; nothing here formats a price.
class RevenueCatPurchasesService implements PurchasesService {
  RevenueCatPurchasesService._() {
    Purchases.addCustomerInfoUpdateListener(_onCustomerInfo);
  }

  /// Configures the SDK if this build has a key for the platform, and
  /// otherwise — or if configuring fails — returns the unconnected store, so
  /// a missing key can never stop the app from starting.
  static Future<PurchasesService> connect() async {
    final String? key = RevenueCatKeys.current();
    if (key == null) return const StoreNotConnectedService();
    try {
      if (kDebugMode) await Purchases.setLogLevel(LogLevel.info);
      await Purchases.configure(PurchasesConfiguration(key));
      return RevenueCatPurchasesService._();
    } on Object catch (error) {
      debugPrint('RevenueCat could not be configured: $error');
      return const StoreNotConnectedService();
    }
  }

  final StreamController<bool> _pro = StreamController<bool>.broadcast();

  void _onCustomerInfo(CustomerInfo info) => _pro.add(_isPro(info));

  static bool _isPro(CustomerInfo info) =>
      info.entitlements.active.containsKey(RevenueCatKeys.entitlement);

  @override
  bool get isConfigured => true;

  @override
  Stream<bool> get proChanges => _pro.stream;

  Future<Offering?> _offering() async =>
      (await Purchases.getOfferings()).current;

  static Package? _packageFor(Offering offering, ProPlan plan) =>
      switch (plan) {
        ProPlan.yearly => offering.annual,
        ProPlan.monthly => offering.monthly,
      };

  @override
  Future<List<PlanPrice>> prices() async {
    try {
      final Offering? offering = await _offering();
      if (offering == null) return const <PlanPrice>[];
      return <PlanPrice>[
        for (final ProPlan plan in ProPlan.values)
          if (_packageFor(offering, plan) case final Package p)
            PlanPrice(
              plan: plan,
              priceLabel: p.storeProduct.priceString,
              perMonthLabel: plan == ProPlan.yearly
                  ? p.storeProduct.pricePerMonthString
                  : null,
            ),
      ];
    } on PlatformException catch (e) {
      debugPrint('RevenueCat offerings unavailable: ${e.message}');
      return const <PlanPrice>[];
    }
  }

  @override
  Future<bool> purchase(ProPlan plan) async {
    final Offering? offering = await _offering();
    final Package? package = offering == null
        ? null
        : _packageFor(offering, plan);
    if (package == null) {
      throw const PurchaseFailure(
        'That plan is not available in your store yet.',
      );
    }
    try {
      final PurchaseResult result = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      return _isPro(result.customerInfo);
    } on PlatformException catch (e) {
      final PurchasesErrorCode code = PurchasesErrorHelper.getErrorCode(e);
      // Backing out of the store sheet is a choice, not an error.
      if (code == PurchasesErrorCode.purchaseCancelledError) return false;
      throw PurchaseFailure(_messageFor(code, e));
    }
  }

  @override
  Future<bool> restore() async {
    try {
      return _isPro(await Purchases.restorePurchases());
    } on PlatformException catch (e) {
      throw PurchaseFailure(
        _messageFor(PurchasesErrorHelper.getErrorCode(e), e),
      );
    }
  }

  @override
  Future<bool> hasPro() async {
    try {
      return _isPro(await Purchases.getCustomerInfo());
    } on PlatformException catch (e) {
      debugPrint('RevenueCat customer info unavailable: ${e.message}');
      return false;
    }
  }

  static String _messageFor(PurchasesErrorCode code, PlatformException e) =>
      switch (code) {
        PurchasesErrorCode.networkError =>
          'No connection to the store. Check your connection and try again.',
        PurchasesErrorCode.paymentPendingError =>
          'Payment pending. Pro unlocks as soon as the store confirms it.',
        PurchasesErrorCode.purchaseNotAllowedError =>
          'Purchases are not allowed on this device.',
        PurchasesErrorCode.productAlreadyPurchasedError =>
          'You already own Pro. Tap Restore purchases.',
        _ => e.message ?? 'The purchase could not be completed.',
      };
}
