import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histox/core/services/purchases_service.dart';
import 'package:histox/core/services/revenuecat_service.dart';

class _ConnectedStore implements PurchasesService {
  @override
  bool get isConfigured => true;

  @override
  Future<List<PlanPrice>> prices() async => const <PlanPrice>[];

  @override
  Future<bool> purchase(ProPlan plan) async => false;

  @override
  Future<bool> restore() async => false;

  @override
  Future<bool> hasPro() async => false;

  @override
  Stream<bool> get proChanges => const Stream<bool>.empty();
}

/// A connected store whose entitlement the test can flip.
class _LiveStore extends _ConnectedStore {
  final StreamController<bool> changes = StreamController<bool>();

  @override
  Stream<bool> get proChanges => changes.stream;
}

void main() {
  test(
    'with no store connected, the preview unlock grants Pro for the session',
    () {
      final ProviderContainer c = ProviderContainer();
      addTearDown(c.dispose);

      expect(c.read(proAccessProvider).hasPro, isFalse);
      c.read(proAccessProvider.notifier).unlockPreview();
      expect(c.read(proAccessProvider).hasPro, isTrue);
      expect(c.read(proAccessProvider).purchased, isFalse);
    },
  );

  test('once a store is connected, the preview unlock does nothing', () {
    final ProviderContainer c = ProviderContainer(
      overrides: [
        purchasesServiceProvider.overrideWithValue(_ConnectedStore()),
      ],
    );
    addTearDown(c.dispose);

    c.read(proAccessProvider.notifier).unlockPreview();
    expect(c.read(proAccessProvider).hasPro, isFalse);
  });

  test('the unconnected store refuses to sell or restore', () async {
    const StoreNotConnectedService store = StoreNotConnectedService();
    expect(await store.prices(), isEmpty);
    expect(
      store.purchase(ProPlan.yearly),
      throwsA(isA<StoreUnavailableException>()),
    );
    expect(store.restore(), throwsA(isA<StoreUnavailableException>()));
  });

  test(
    'with no RevenueCat key in the build, the store stays unconnected',
    () async {
      final PurchasesService store = await RevenueCatPurchasesService.connect();
      expect(store.isConfigured, isFalse);
    },
  );

  test('a store-side entitlement change reaches every Pro gate', () async {
    final _LiveStore store = _LiveStore();
    final ProviderContainer c = ProviderContainer(
      overrides: [purchasesServiceProvider.overrideWithValue(store)],
    );
    addTearDown(c.dispose);

    expect(c.read(proAccessProvider).hasPro, isFalse);
    store.changes.add(true);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(proAccessProvider).hasPro, isTrue);

    // An expiry takes it away again.
    store.changes.add(false);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(proAccessProvider).hasPro, isFalse);
  });
}
