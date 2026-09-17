// Visual QA: renders every wireframe screen with the app's real fonts and
// writes PNGs, so the implementation can be compared against the artboards.
//
//   MN_SHOTS_DIR=build/screens flutter test tool/screens/capture_test.dart
//
// Not part of the test suite (it lives under tool/, which `flutter test`
// does not scan by default) and it asserts nothing: it is a camera. The
// market data here is synthetic on purpose — it only has to put pixels in
// the right places — and none of it ships.
// A camera run through flutter_test, so it uses the test-only hooks (mock
// preferences, a fixed Pivot clock) the same way the suite does.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histox/app/router.dart';
import 'package:histox/app/theme.dart';
import 'package:histox/core/market/candle.dart';
import 'package:histox/core/market/instrument.dart';
import 'package:histox/core/market/instrument_catalog.dart';
import 'package:histox/core/market/market_data_service.dart';
import 'package:histox/core/services/progress_service.dart';
import 'package:histox/core/services/purchases_service.dart';
import 'package:histox/core/services/run_history_service.dart';
import 'package:histox/features/daily_pivot/model/pivot_models.dart';
import 'package:histox/features/daily_pivot/pivot_home.dart';
import 'package:histox/features/daily_pivot/services/pivot_backend.dart';
import 'package:histox/features/daily_pivot/services/pivot_controller.dart';
import 'package:histox/features/daily_pivot/services/pivot_price_service.dart';
import 'package:histox/features/daily_pivot/services/pivot_store.dart';
import 'package:histox/features/live_market/live_market_home.dart';
import 'package:histox/features/live_market/services/live_quotes.dart';
import 'package:histox/features/paywall/paywall_screen.dart';
import 'package:histox/features/profile/model/nerve_profile.dart';
import 'package:histox/features/profile/nerve_profile_screen.dart';
import 'package:histox/features/profile/widgets/nerve_share_card.dart';
import 'package:histox/features/simulator/campaign/level_repository.dart';
import 'package:histox/features/simulator/engine/level_model.dart';
import 'package:histox/features/simulator/engine/simulation_mode.dart';
import 'package:histox/features/simulator/level/level_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Size _phone = Size(390, 844);
final String _out = Platform.environment['MN_SHOTS_DIR'] ?? 'build/screens';

Future<void> _loadFonts() async {
  Future<void> load(String family, String path) async {
    final Uint8List bytes = File(path).readAsBytesSync();
    final FontLoader loader = FontLoader(family)
      ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }

  await load('Inter', 'assets/fonts/Inter.ttf');
  await load('JetBrainsMono', 'assets/fonts/JetBrainsMono.ttf');
  // flutter_tester lives in <flutter>/bin/cache/artifacts/engine/<platform>.
  final Directory artifacts = File(
    Platform.resolvedExecutable,
  ).parent.parent.parent;
  await load(
    'MaterialIcons',
    '${artifacts.path}/material_fonts/materialicons-regular.otf',
  );
}

final GlobalKey _frame = GlobalKey();

Future<void> _save(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        _frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    Directory(_out).createSync(recursive: true);
    File('$_out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<SharedPreferences> _prefs(Map<String, Object> seed) async {
  SharedPreferences.setMockInitialValues(seed);
  return SharedPreferences.getInstance();
}

/// Serves bundled assets straight from disk. rootBundle decodes anything over
/// 50KB (the level manifest included) on a background isolate, which never
/// completes inside a widget test's fake-async zone — so without this, the
/// screens would render their loading state instead of their real one.
class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.view(File(key).readAsBytesSync().buffer);

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(key).readAsStringSync();
}

Future<void> _mount(
  WidgetTester tester,
  Widget child, {
  required SharedPreferences prefs,
  List<dynamic> overrides = const <dynamic>[],
  Size size = _phone,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        pivotPriceServiceProvider.overrideWithValue(_FakePrices()),
        levelRepositoryProvider.overrideWithValue(
          LevelRepository(bundle: _DiskBundle()),
        ),
        ...overrides,
      ],
      child: RepaintBoundary(
        key: _frame,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: child,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

// --------------------------------------------------------------- fixtures

/// Synthetic 15-minute BTC tape for the Pivot shots.
List<Candle> _tape({double from = 79400, double to = 80300, int n = 40}) {
  final math.Random r = math.Random(7);
  final DateTime start = DateTime.now().toUtc().subtract(
    Duration(minutes: 15 * n),
  );
  double last = from;
  return <Candle>[
    for (int i = 0; i < n; i++)
      () {
        final double target = from + (to - from) * i / (n - 1);
        final double close = target + (r.nextDouble() - 0.5) * 120;
        final Candle c = Candle(
          date: start.add(Duration(minutes: 15 * i)),
          open: last,
          high: math.max(last, close) + r.nextDouble() * 40,
          low: math.min(last, close) - r.nextDouble() * 40,
          close: close,
          volume: 10,
        );
        last = close;
        return c;
      }(),
  ];
}

class _FakePrices extends PivotPriceService {
  _FakePrices() : super(MarketDataService(providers: const []));

  @override
  String get sourceLabel => 'Binance · live';

  @override
  Future<double> strikeFor(String dayKey) async => 80066;

  @override
  Future<double?> closeFor(String dayKey) async => 80914;

  @override
  Future<Quote> live() async => Quote(
    instrument: PivotPriceService.btc,
    price: 80359,
    previousClose: 79800,
    asOf: DateTime.now(),
    source: 'Binance · live',
  );

  @override
  Future<List<Candle>> tape(DateTime nowUtc) async => _tape();
}

class _Crowd implements PivotBackend {
  const _Crowd();

  @override
  String get sourceLabel => 'CROWD SERVER';

  @override
  Future<void> submitVote(PivotVote vote) async {}

  @override
  Future<PivotTally> tally(String dayKey) async => const PivotTally(
    yes: 819,
    no: 385,
    source: 'CROWD SERVER',
    isAggregate: true,
  );
}

class _FixedPivot extends PivotController {
  _FixedPivot(this.at);

  final DateTime at;

  @override
  PivotViewState build() {
    clock = () => at;
    return super.build();
  }
}

class _Pro extends ProAccessNotifier {
  @override
  ProAccess build() => const ProAccess(purchased: true, previewUnlocked: false);
}

class _Quotes extends LiveQuotes {
  @override
  LiveQuotesState build() {
    Quote q(String id, double price, double prev, String source, int ageMin) =>
        Quote(
          instrument: InstrumentCatalog.byId(id)!,
          price: price,
          previousClose: prev,
          asOf: DateTime.now().subtract(Duration(minutes: ageMin)),
          source: source,
        );
    return LiveQuotesState(
      loading: false,
      updatedAt: DateTime.now(),
      quotes: <String, Quote>{
        'yahoo:^NSEI': q(
          'yahoo:^NSEI',
          23898,
          23810,
          'Yahoo Finance · delayed',
          15,
        ),
        'binance:BTCUSDT': q(
          'binance:BTCUSDT',
          80066,
          79120,
          'Binance · live',
          0,
        ),
        'yahoo:^GSPC': q(
          'yahoo:^GSPC',
          5611,
          5630,
          'Yahoo Finance · delayed',
          15,
        ),
      },
    );
  }

  @override
  void setPolling(bool on) {}

  @override
  Future<void> refresh({bool force = false}) async {}
}

String _day(int offset) =>
    PivotClock.dayKey(DateTime.now().toUtc().add(Duration(days: offset)));

DateTime _ist(String day, int h, int m) =>
    PivotClock.openUtc(day).add(Duration(hours: h - 9, minutes: m));

Future<Map<String, Object>> _pivotSeed({
  required bool voted,
  bool seen = false,
  int streakDays = 4,
}) async {
  final SharedPreferences p = await _prefs(<String, Object>{});
  final PivotStore store = PivotStore(p);
  for (int i = 1; i <= streakDays; i++) {
    final String d = _day(-i);
    await store.saveVote(
      PivotVote(
        dayKey: d,
        choice: PivotChoice.yes,
        sealedAt: _ist(d, 9, 4),
        strike: 79000,
      ),
    );
    await store.saveAward(
      d,
      const PivotAward(base: 10, contrarianBonus: 0, multiplier: 1),
    );
  }
  if (voted) {
    await store.saveVote(
      PivotVote(
        dayKey: _day(0),
        choice: PivotChoice.yes,
        sealedAt: _ist(_day(0), 9, 4),
        strike: 80066,
      ),
    );
  }
  if (seen) await store.markOutcomeSeen(_day(0));
  return <String, Object>{
    for (final String k in p.getKeys()) k: p.get(k)!,
    'mn.progress.pivot_points.v1': 1230,
  };
}

RunRecord _run(
  String id,
  String title,
  int score,
  List<DecisionSample> s,
  int daysAgo,
) => RunRecord(
  levelId: id,
  title: title,
  mode: 'beginner',
  score: score,
  playedAt: DateTime.now().subtract(Duration(days: daysAgo)),
  samples: s,
);

DecisionSample _d(String a, double dd, double speed, double sec) =>
    DecisionSample(
      action: a,
      drawdown: dd,
      crashSpeed: speed,
      credit: a == 'sell' ? 0 : 1,
      seconds: sec,
    );

List<RunRecord> _history(int n) => <RunRecord>[
  _run('black_monday_1987', 'Black Monday', 44, <DecisionSample>[
    _d('sell', 0.14, 0.05, 4),
    _d('hold', 0.2, 0.006, 9),
  ], 20),
  _run('gfc_2008', 'The Global Financial Crisis', 48, <DecisionSample>[
    _d('hold', 0.18, 0.004, 8),
    _d('sell', 0.16, 0.03, 5),
  ], 18),
  _run('crypto_winter_2018', 'Crypto Winter', 52, <DecisionSample>[
    _d('hold', 0.25, 0.006, 7),
    _d('buy_dip', 0.3, 0.004, 11),
  ], 15),
  _run('dotcom_2000', 'The Dot-Com Crash', 70, <DecisionSample>[
    _d('hold', 0.22, 0.005, 6),
    _d('sell', 0.31, 0.03, 4),
  ], 10),
  _run('covid_crash_2020', 'The COVID Crash', 81, <DecisionSample>[
    _d('hold', 0.3, 0.02, 5),
    _d('sell', 0.33, 0.04, 3),
  ], 6),
  _run('taper_tantrum_2013', 'The Taper Tantrum', 84, <DecisionSample>[
    _d('hold', 0.12, 0.004, 6),
    _d('buy_dip', 0.16, 0.004, 7),
  ], 4),
  _run('svb_2023', 'SVB & the Regional Banking Crisis', 86, <DecisionSample>[
    _d('hold', 0.15, 0.01, 6),
    _d('sell', 0.29, 0.035, 4),
  ], 2),
  _run('dotcom_2000', 'The Dot-Com Crash', 88, <DecisionSample>[
    _d('hold', 0.28, 0.006, 5),
    _d('sell', 0.36, 0.03, 4),
  ], 0),
].take(n).toList();

/// Read straight from disk rather than through rootBundle: above 50KB the
/// bundle decodes on a background isolate, and that future never completes
/// inside a widget test's fake-async zone.
Future<SimulationLevel> _level(WidgetTester tester, String id) async {
  final Map<String, dynamic> manifest =
      jsonDecode(File(LevelRepository.manifestPath).readAsStringSync())
          as Map<String, dynamic>;
  final Map<String, dynamic> row = (manifest['levels'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .firstWhere((Map<String, dynamic> r) => r['id'] == id);
  return SimulationLevel.fromJson(
    levelJson:
        jsonDecode(File('data/simulator_levels/$id.json').readAsStringSync())
            as Map<String, dynamic>,
    scriptJson:
        jsonDecode(
              File(
                'data/simulator_levels/${id}_script.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>,
    description: row['description'] as String?,
  );
}

Future<void> _tick(WidgetTester tester, int candles) async {
  for (int i = 0; i < candles; i++) {
    await tester.pump(const Duration(milliseconds: 91));
  }
}

// ------------------------------------------------------------------ shots

void main() {
  setUpAll(_loadFonts);

  testWidgets('01 campaign home', (WidgetTester tester) async {
    final Map<String, Object> seed = await _pivotSeed(
      voted: false,
      streakDays: 7,
    );
    seed['mn.onboarding.seen.v1'] = true;
    seed['mn.progress.pivot_points.v1'] = 142;
    seed['mn.progress.levels.v1'] = jsonEncode(<String, dynamic>{
      for (final (String id, int s) in <(String, int)>[
        ('black_monday_1987', 84),
        ('dotcom_2000', 72),
        ('gfc_india_2008', 81),
      ])
        id: <String, dynamic>{
          'level_id': id,
          'best_score': s,
          'best_pnl': 0,
          'times_played': 1,
          'modes_played': <String>['beginner'],
        },
    });
    await _mount(tester, const AppRoot(), prefs: await _prefs(seed));
    await tester.pump(const Duration(seconds: 1));
    await _save(tester, '01_campaign_home');
  });

  testWidgets('02-05 level states', (WidgetTester tester) async {
    final SimulationLevel level = await _level(tester, 'gfc_2008');
    await _mount(
      tester,
      LevelScreen(level: level, mode: SimulationMode.beginner),
      prefs: await _prefs(<String, Object>{}),
    );
    await _save(tester, '02_level_idle');

    await tester.tap(find.text('START RUN'));
    await tester.pump();
    // Play to the first halt.
    for (int i = 0; i < 400; i++) {
      await _tick(tester, 1);
      if (find.text('WHAT DO YOU DO?').evaluate().isNotEmpty) break;
    }
    await tester.pump(const Duration(milliseconds: 600));
    await _save(tester, '04_level_halted');

    // Answer it, run on a little, and pause: the playing state with one call
    // already marked on the rail, as artboard 1b draws it.
    await tester.tap(find.text('HOLD'));
    await tester.pump();
    for (int i = 0; i < 12; i++) {
      await _tick(tester, 1);
      if (find.text('WHAT DO YOU DO?').evaluate().isNotEmpty) break;
    }
    if (find.byIcon(Icons.pause).evaluate().isNotEmpty) {
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump(const Duration(milliseconds: 300));
      await _save(tester, '03_level_playing');
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
    }

    // Finish the run holding every call, then open the debrief.
    for (int i = 0; i < 600; i++) {
      await _tick(tester, 1);
      final Finder hold = find.text('HOLD');
      if (hold.evaluate().isNotEmpty) {
        await tester.tap(hold);
        await tester.pump();
      }
      if (find.text('REVEAL & SCORE').evaluate().isNotEmpty) break;
    }
    await tester.tap(find.text('REVEAL & SCORE'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await _save(tester, '06_debrief');
  });

  testWidgets('05 advanced run', (WidgetTester tester) async {
    final SimulationLevel level = await _level(tester, 'gfc_2008');
    await _mount(
      tester,
      LevelScreen(level: level, mode: SimulationMode.advanced),
      prefs: await _prefs(<String, Object>{}),
    );
    await tester.tap(find.text('START RUN'));
    await tester.pump();
    await _tick(tester, 40);
    await tester.tap(find.text('SELL'));
    await tester.pump();
    await _tick(tester, 45);
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump(const Duration(milliseconds: 400));
    await _save(tester, '05_level_advanced');
  });

  testWidgets('07-11 daily pivot', (WidgetTester tester) async {
    final String today = _day(0);
    Future<void> shot(
      String name,
      DateTime at,
      Map<String, Object> seed, {
      List<dynamic> extra = const <dynamic>[],
    }) async {
      await _mount(
        tester,
        const PivotHome(),
        prefs: await _prefs(seed),
        overrides: <dynamic>[
          pivotControllerProvider.overrideWith(() => _FixedPivot(at)),
          ...extra,
        ],
      );
      await tester.pump(const Duration(seconds: 1));
      await _save(tester, name);
      await tester.pumpWidget(const SizedBox());
    }

    await shot(
      '07_pivot_vote',
      _ist(today, 9, 1),
      await _pivotSeed(voted: false),
    );
    await shot(
      '08_pivot_locked',
      _ist(today, 10, 48),
      await _pivotSeed(voted: true),
    );
    await shot(
      '09_pivot_poll_closed_low_votes',
      _ist(today, 17, 0),
      await _pivotSeed(voted: true),
    );
    await shot(
      '09b_pivot_poll_closed_crowd',
      _ist(today, 17, 0),
      await _pivotSeed(voted: true),
      extra: <dynamic>[pivotBackendProvider.overrideWithValue(const _Crowd())],
    );
    await shot(
      '10_pivot_resolved',
      _ist(today, 17, 2),
      await _pivotSeed(voted: true, seen: true),
    );
  });

  testWidgets('12 paywall', (WidgetTester tester) async {
    final SimulationLevel level = await _level(tester, 'gfc_2008');
    await _mount(
      tester,
      PaywallScreen(
        score: 72,
        practiceYear: '2008',
        backdrop: <double>[for (final Candle c in level.candles) c.close],
        dismissLabel: 'NOT NOW — BACK TO THE DEBRIEF',
      ),
      prefs: await _prefs(<String, Object>{}),
    );
    await tester.pump(const Duration(seconds: 1));
    await _save(tester, '12_paywall');
  });

  testWidgets('13 feed states (live markets)', (WidgetTester tester) async {
    await _mount(
      tester,
      const LiveMarketHome(),
      prefs: await _prefs(<String, Object>{}),
      overrides: <dynamic>[liveQuotesProvider.overrideWith(_Quotes.new)],
    );
    await _save(tester, '13_live_markets_feed_states');
  });

  testWidgets('14-17 nerve profile', (WidgetTester tester) async {
    Future<void> shot(String name, int runs, {bool pro = false}) async {
      final SharedPreferences p = await _prefs(<String, Object>{});
      await RunHistoryService(p).save(_history(runs));
      await _mount(
        tester,
        const NerveProfileScreen(),
        prefs: p,
        overrides: <dynamic>[if (pro) proAccessProvider.overrideWith(_Pro.new)],
      );
      await tester.pump(const Duration(seconds: 1));
      await _save(tester, name);
      await tester.pumpWidget(const SizedBox());
    }

    await shot('14_profile_building', 3);
    await shot('15_profile_locked', 8);
    await shot('16_profile_full', 8, pro: true);

    await _mount(
      tester,
      Scaffold(
        body: Center(
          child: NerveShareCard(profile: NerveProfile.from(_history(8))),
        ),
      ),
      prefs: await _prefs(<String, Object>{}),
    );
    await _save(tester, '17_profile_share_card');
  });
}
