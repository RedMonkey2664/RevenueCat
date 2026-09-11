import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_nerve/core/services/purchases_service.dart';

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
}
