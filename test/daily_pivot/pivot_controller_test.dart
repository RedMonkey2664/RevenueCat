import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histox/core/market/candle.dart';
import 'package:histox/core/market/instrument.dart';
import 'package:histox/core/market/market_data_service.dart';
import 'package:histox/core/services/progress_service.dart';
import 'package:histox/features/daily_pivot/model/pivot_models.dart';
import 'package:histox/features/daily_pivot/services/pivot_backend.dart';
import 'package:histox/features/daily_pivot/services/pivot_controller.dart';
import 'package:histox/features/daily_pivot/services/pivot_price_service.dart';
import 'package:histox/features/daily_pivot/services/pivot_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _day = '2026-09-07';

DateTime _ist(int h, int m) =>
    PivotClock.openUtc(_day).add(Duration(hours: h - 9, minutes: m));

class _Prices extends PivotPriceService {
  _Prices({this.close = 80914}) : super(MarketDataService(providers: const []));

  final double? close;
  int strikeCalls = 0;

  @override
  String get sourceLabel => 'Binance · live';

  @override
  Future<double> strikeFor(String dayKey) async {
    strikeCalls++;
    return 80066;
  }

  @override
  Future<double?> closeFor(String dayKey) async => close;

  @override
  Future<Quote> live() async => Quote(
    instrument: PivotPriceService.btc,
    price: 80359,
    previousClose: 80000,
    asOf: DateTime.utc(2026, 9, 7),
    source: 'Binance · live',
  );

  @override
  Future<List<Candle>> tape(DateTime nowUtc) async => const <Candle>[];
}

class _Crowd implements PivotBackend {
  const _Crowd(this.yes, this.no);

  final int yes;
  final int no;

  @override
  String get sourceLabel => 'SERVER';

  @override
  Future<void> submitVote(PivotVote vote) async {}

  @override
  Future<PivotTally> tally(String dayKey) async =>
      PivotTally(yes: yes, no: no, source: 'SERVER', isAggregate: true);
}

class _At extends PivotController {
  _At(this.at);

  final DateTime at;

  @override
  PivotViewState build() {
    clock = () => at;
    return super.build();
  }
}

Future<void> _settle() async {
  for (int i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<ProviderContainer> _make(
  DateTime at, {
  _Prices? prices,
  PivotBackend? backend,
  Future<void> Function(PivotStore store)? seed,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  if (seed != null) await seed(PivotStore(prefs));
  final ProviderContainer c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      pivotPriceServiceProvider.overrideWithValue(prices ?? _Prices()),
      pivotControllerProvider.overrideWith(() => _At(at)),
      if (backend != null) pivotBackendProvider.overrideWithValue(backend),
    ],
  );
  addTearDown(c.dispose);
  c.read(pivotControllerProvider);
  await _settle();
  return c;
}

Future<void> _votedYes(PivotStore store) => store.saveVote(
  PivotVote(
    dayKey: _day,
    choice: PivotChoice.yes,
    sealedAt: _ist(9, 4),
    strike: 80066,
  ),
);

void main() {
  test('before 09:00 IST there is no question yet', () async {
    final ProviderContainer c = await _make(_ist(8, 30));
    expect(c.read(pivotControllerProvider).phase, PivotPhase.beforeOpen);
  });

  test(
    'open: asks against the 09:00 strike, and seals exactly one vote',
    () async {
      final _Prices prices = _Prices();
      final ProviderContainer c = await _make(_ist(10, 0), prices: prices);
      final PivotController pivot = c.read(pivotControllerProvider.notifier);

      expect(c.read(pivotControllerProvider).phase, PivotPhase.voting);
      expect(c.read(pivotControllerProvider).strike, 80066);
      expect(c.read(pivotNeedsAttentionProvider), isTrue);

      await pivot.vote(PivotChoice.no);
      expect(c.read(pivotControllerProvider).phase, PivotPhase.locked);
      expect(c.read(pivotControllerProvider).vote!.choice, PivotChoice.no);

      await pivot.vote(PivotChoice.yes);
      expect(
        c.read(pivotControllerProvider).vote!.choice,
        PivotChoice.no,
        reason: 'a sealed vote cannot be changed',
      );

      // The strike is fetched once and then read from the store.
      await pivot.load();
      expect(prices.strikeCalls, 1);
    },
  );

  test(
    'after 17:00 a right call is paid once, into the shared total',
    () async {
      final ProviderContainer c = await _make(_ist(17, 2), seed: _votedYes);
      final PivotViewState s = c.read(pivotControllerProvider);

      expect(s.phase, PivotPhase.pollClosed);
      expect(s.outcome!.winner, PivotChoice.yes);
      expect(s.award!.total, 10);
      expect(c.read(progressProvider).pivotBonusPoints, 10);

      await c.read(pivotControllerProvider.notifier).showOutcome();
      expect(c.read(pivotControllerProvider).phase, PivotPhase.resolved);

      await c.read(pivotControllerProvider.notifier).load();
      expect(
        c.read(progressProvider).pivotBonusPoints,
        10,
        reason: 'reloading must never pay the same day twice',
      );
    },
  );

  test(
    'a right call against a real majority pays the contrarian rate',
    () async {
      final ProviderContainer c = await _make(
        _ist(17, 2),
        seed: _votedYes,
        backend: const _Crowd(100, 900),
      );
      expect(c.read(pivotControllerProvider).award!.total, 24);
    },
  );

  test(
    'the local backend never counts as a crowd, so no contrarian bonus',
    () async {
      final ProviderContainer c = await _make(_ist(17, 2), seed: _votedYes);
      final PivotViewState s = c.read(pivotControllerProvider);
      expect(s.tally!.isAggregate, isFalse);
      expect(s.award!.contrarianBonus, 0);
    },
  );

  test('without a 17:00 price the day stays unresolved and unpaid', () async {
    final ProviderContainer c = await _make(
      _ist(17, 2),
      prices: _Prices(close: null),
      seed: _votedYes,
    );
    final PivotViewState s = c.read(pivotControllerProvider);
    expect(s.phase, PivotPhase.pollClosed);
    expect(s.outcome, isNull);
    expect(c.read(progressProvider).pivotBonusPoints, 0);
  });

  test('closed with no vote is a missed day', () async {
    final ProviderContainer c = await _make(_ist(18, 0));
    expect(c.read(pivotControllerProvider).phase, PivotPhase.missed);
  });

  test('streak counts consecutive resolved days up to yesterday', () async {
    final ProviderContainer c = await _make(
      _ist(10, 0),
      seed: (PivotStore store) async {
        for (final String d in <String>[
          '2026-09-06',
          '2026-09-05',
          '2026-09-04',
        ]) {
          await store.saveAward(d, PivotAward.none);
        }
      },
    );
    expect(c.read(pivotControllerProvider).streak, 3);
    expect(c.read(pivotStreakProvider), 3);
  });
}
