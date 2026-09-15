import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Pro subscription, behind one small interface (MONETIZATION.md).
///
/// The live implementation is RevenueCat (`revenuecat_service.dart`),
/// configured at startup from the public SDK key for the platform. A build
/// with no key — the web preview, a test, a developer without a RevenueCat
/// project — runs on [StoreNotConnectedService], which is honest about it:
/// no prices, no purchase, no restore, and the paywall says the store is not
/// connected rather than showing a price it cannot charge.
///
/// Nothing else in the app talks to a store.
enum ProPlan { yearly, monthly }

@immutable
class PlanPrice {
  const PlanPrice({
    required this.plan,
    required this.priceLabel,
    this.perMonthLabel,
  });

  final ProPlan plan;

  /// Localised by the store, e.g. "₹1,499". Never formatted by us.
  final String priceLabel;

  /// The yearly plan's monthly equivalent, as the store reports it.
  final String? perMonthLabel;
}

/// A purchase or restore the store refused, worded for the player.
class PurchaseFailure implements Exception {
  const PurchaseFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class StoreUnavailableException implements Exception {
  const StoreUnavailableException();

  @override
  String toString() => 'The app store is not connected in this build.';
}

abstract class PurchasesService {
  /// Whether a store is connected in this build.
  bool get isConfigured;

  /// Region-specific prices from the store. Empty when there is no store.
  Future<List<PlanPrice>> prices();

  /// Returns whether the purchase completed with the `pro` entitlement.
  Future<bool> purchase(ProPlan plan);

  /// Returns whether a `pro` entitlement was restored.
  Future<bool> restore();

  Future<bool> hasPro();

  /// Emits the `pro` entitlement whenever the store reports a change —
  /// a renewal, an expiry, a purchase finished on another device.
  Stream<bool> get proChanges;
}

/// A build with no RevenueCat key. Everything that would touch a store refuses.
class StoreNotConnectedService implements PurchasesService {
  const StoreNotConnectedService();

  @override
  bool get isConfigured => false;

  @override
  Future<List<PlanPrice>> prices() async => const <PlanPrice>[];

  @override
  Future<bool> purchase(ProPlan plan) =>
      Future<bool>.error(const StoreUnavailableException());

  @override
  Future<bool> restore() =>
      Future<bool>.error(const StoreUnavailableException());

  @override
  Future<bool> hasPro() async => false;

  @override
  Stream<bool> get proChanges => const Stream<bool>.empty();
}

final Provider<PurchasesService> purchasesServiceProvider =
    Provider<PurchasesService>((Ref ref) => const StoreNotConnectedService());

/// Whether this player can open Pro content right now.
@immutable
class ProAccess {
  const ProAccess({required this.purchased, required this.previewUnlocked});

  static const ProAccess none = ProAccess(
    purchased: false,
    previewUnlocked: false,
  );

  /// A real `pro` entitlement from the store.
  final bool purchased;

  /// PREVIEW BUILDS ONLY. With no store connected there is no way to buy
  /// Pro, and gating two-thirds of the campaign behind a purchase nobody can
  /// make would turn the demo into a locked door. The paywall therefore
  /// offers "continue without Pro" — but only while
  /// [PurchasesService.isConfigured] is false, and only for this session. The
  /// moment a real store is wired in, the option disappears on its own.
  final bool previewUnlocked;

  bool get hasPro => purchased || previewUnlocked;
}

final NotifierProvider<ProAccessNotifier, ProAccess> proAccessProvider =
    NotifierProvider<ProAccessNotifier, ProAccess>(ProAccessNotifier.new);

class ProAccessNotifier extends Notifier<ProAccess> {
  @override
  ProAccess build() {
    final PurchasesService service = ref.watch(purchasesServiceProvider);
    if (service.isConfigured) {
      final StreamSubscription<bool> changes = service.proChanges.listen(
        (bool pro) => state = ProAccess(
          purchased: pro,
          previewUnlocked: state.previewUnlocked,
        ),
      );
      ref.onDispose(changes.cancel);
      service.hasPro().then((bool pro) {
        if (pro) {
          state = ProAccess(
            purchased: true,
            previewUnlocked: state.previewUnlocked,
          );
        }
      }).ignore();
    }
    return ProAccess.none;
  }

  /// See [ProAccess.previewUnlocked]. A no-op once a store is connected.
  void unlockPreview() {
    if (ref.read(purchasesServiceProvider).isConfigured) return;
    state = ProAccess(purchased: state.purchased, previewUnlocked: true);
  }

  void markPurchased() => state = ProAccess(
    purchased: true,
    previewUnlocked: state.previewUnlocked,
  );
}
