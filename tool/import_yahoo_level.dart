// Builds equity campaign levels from Yahoo Finance's chart endpoint.
//
//   dart run tool/import_yahoo_level.dart gfc_2008
//   dart run tool/import_yahoo_level.dart --all
//
// ⚠ LICENSING — READ BEFORE SHIPPING ⚠
//
// This source is NOT cleared for redistribution. Two separate problems:
//
//   1. Yahoo's terms do not permit bundling their data inside an app.
//   2. Index levels (S&P 500, Sensex, Nifty) are the index provider's IP
//      regardless of who serves them — which is why FRED caps its own S&P
//      series at ten years.
//
// So every level this writes carries "licence": "unverified", and the app
// surfaces that. These levels are real and playable for development and demo;
// they are not clear to publish. Swapping to a licensed vendor is a change to
// `fetchDaily` below and nothing else — the windows, the ladder and the
// derived verdicts all stay.
//
// Everything factual is still computed from the real series: prices, dates and
// optimal_action are never typed by hand (LEVELS.md).

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:market_nerve/features/simulator/engine/candle_model.dart';
import 'package:market_nerve/features/simulator/engine/pause_ladder.dart';

const String _ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Safari/537.36';

class Recipe {
  const Recipe({
    required this.id,
    required this.symbol,
    required this.assetName,
    required this.assetClass,
    required this.from,
    required this.to,
    this.targetPausePoints = 12,
    this.minFromPeak = PauseLadder.defaultMinFromPeak,
  });

  final String id;
  final String symbol;
  final String assetName;
  final String assetClass;

  /// Includes lead-in before the event so the run does not open mid-fall.
  final DateTime from;
  final DateTime to;

  final int targetPausePoints;

  /// How far below the running peak counts as a moment worth asking about.
  /// LEVELS.md describes several of these events as deliberately mild — a
  /// taper tantrum or a demonetisation shock never falls 8%, so holding the
  /// default floor would silently drop them from the campaign.
  final double minFromPeak;
}

final List<Recipe> recipes = <Recipe>[
  // ---- International (us_equity) ----
  Recipe(
    id: 'black_monday_1987',
    symbol: '^GSPC',
    assetName: 'S&P 500 Index',
    assetClass: 'us_equity',
    from: DateTime.utc(1987, 7, 1),
    to: DateTime.utc(1988, 6, 30),
  ),
  Recipe(
    id: 'dotcom_2000',
    symbol: '^IXIC',
    assetName: 'Nasdaq Composite Index',
    assetClass: 'us_equity',
    from: DateTime.utc(2000, 1, 1),
    to: DateTime.utc(2002, 12, 31),
    targetPausePoints: 14,
  ),
  Recipe(
    id: 'taper_tantrum_2013',
    symbol: '^GSPC',
    assetName: 'S&P 500 Index',
    assetClass: 'us_equity',
    from: DateTime.utc(2013, 4, 1),
    to: DateTime.utc(2013, 12, 31),
    minFromPeak: 0.030,
  ),
  Recipe(
    id: 'debt_ceiling_2011',
    symbol: '^GSPC',
    assetName: 'S&P 500 Index',
    assetClass: 'us_equity',
    from: DateTime.utc(2011, 5, 1),
    to: DateTime.utc(2012, 3, 31),
    minFromPeak: 0.045,
  ),
  Recipe(
    id: 'china_selloff_2015',
    symbol: '^GSPC',
    assetName: 'S&P 500 Index',
    assetClass: 'us_equity',
    from: DateTime.utc(2015, 5, 1),
    to: DateTime.utc(2016, 6, 30),
    minFromPeak: 0.040,
  ),
  Recipe(
    id: 'gfc_2008',
    symbol: '^GSPC',
    assetName: 'S&P 500 Index',
    assetClass: 'us_equity',
    from: DateTime.utc(2007, 10, 1),
    to: DateTime.utc(2009, 6, 30),
    targetPausePoints: 14,
  ),
  Recipe(
    id: 'covid_crash_2020',
    symbol: '^GSPC',
    assetName: 'S&P 500 Index',
    assetClass: 'us_equity',
    from: DateTime.utc(2020, 1, 2),
    to: DateTime.utc(2020, 12, 31),
  ),
  Recipe(
    id: 'svb_2023',
    symbol: '^GSPC',
    assetName: 'S&P 500 Index',
    assetClass: 'us_equity',
    from: DateTime.utc(2022, 12, 1),
    to: DateTime.utc(2023, 10, 31),
    minFromPeak: 0.030,
  ),

  // ---- Indian (india_equity) ----
  Recipe(
    id: 'india_black_monday_2004',
    symbol: '^BSESN',
    assetName: 'BSE Sensex',
    assetClass: 'india_equity',
    from: DateTime.utc(2004, 1, 1),
    to: DateTime.utc(2004, 12, 31),
  ),
  Recipe(
    id: 'ketan_parekh_2001',
    symbol: '^BSESN',
    assetName: 'BSE Sensex',
    assetClass: 'india_equity',
    from: DateTime.utc(2000, 1, 1),
    to: DateTime.utc(2001, 12, 31),
    targetPausePoints: 14,
  ),
  Recipe(
    id: 'india_tremors_2007',
    symbol: '^BSESN',
    assetName: 'BSE Sensex',
    assetClass: 'india_equity',
    from: DateTime.utc(2007, 1, 1),
    to: DateTime.utc(2007, 12, 31),
  ),
  Recipe(
    id: 'yuan_devaluation_2015',
    symbol: '^BSESN',
    assetName: 'BSE Sensex',
    assetClass: 'india_equity',
    from: DateTime.utc(2015, 5, 1),
    to: DateTime.utc(2016, 6, 30),
  ),
  Recipe(
    id: 'demonetisation_2016',
    symbol: '^BSESN',
    assetName: 'BSE Sensex',
    assetClass: 'india_equity',
    from: DateTime.utc(2016, 8, 1),
    to: DateTime.utc(2017, 6, 30),
    minFromPeak: 0.030,
  ),
  Recipe(
    id: 'gfc_india_2008',
    symbol: '^BSESN',
    assetName: 'BSE Sensex',
    assetClass: 'india_equity',
    from: DateTime.utc(2007, 10, 1),
    to: DateTime.utc(2009, 6, 30),
    targetPausePoints: 14,
  ),
  Recipe(
    id: 'covid_india_2020',
    symbol: '^BSESN',
    assetName: 'BSE Sensex',
    assetClass: 'india_equity',
    from: DateTime.utc(2020, 1, 2),
    to: DateTime.utc(2020, 12, 31),
  ),
];

Future<List<Candle>> fetchDaily(Recipe r) async {
  final Uri uri = Uri.https(
    'query1.finance.yahoo.com',
    // Uri.https encodes the path itself; pre-encoding gave %255E and a 404.
    '/v8/finance/chart/${r.symbol}',
    <String, String>{
      'period1': (r.from.millisecondsSinceEpoch ~/ 1000).toString(),
      'period2': (r.to.millisecondsSinceEpoch ~/ 1000).toString(),
      'interval': '1d',
    },
  );

  final http.Response res =
      await http.get(uri, headers: <String, String>{'User-Agent': _ua});
  if (res.statusCode != 200) {
    throw Exception('${r.symbol}: HTTP ${res.statusCode}');
  }

  final Map<String, dynamic> json =
      jsonDecode(res.body) as Map<String, dynamic>;
  final List<dynamic>? results =
      (json['chart'] as Map<String, dynamic>)['result'] as List<dynamic>?;
  if (results == null || results.isEmpty) {
    throw Exception('${r.symbol}: no series for that window');
  }

  final Map<String, dynamic> result = results.first as Map<String, dynamic>;
  final List<dynamic> stamps = result['timestamp'] as List<dynamic>;
  final Map<String, dynamic> q =
      ((result['indicators'] as Map<String, dynamic>)['quote']
          as List<dynamic>)[0] as Map<String, dynamic>;

  final List<dynamic> o = q['open'] as List<dynamic>;
  final List<dynamic> h = q['high'] as List<dynamic>;
  final List<dynamic> l = q['low'] as List<dynamic>;
  final List<dynamic> c = q['close'] as List<dynamic>;

  final List<Candle> out = <Candle>[];
  for (int i = 0; i < stamps.length; i++) {
    // Yahoo returns nulls on non-trading days that slipped into the range.
    if (o[i] == null || h[i] == null || l[i] == null || c[i] == null) continue;
    out.add(
      Candle(
        date: DateTime.fromMillisecondsSinceEpoch(
          (stamps[i] as int) * 1000,
          isUtc: true,
        ),
        open: (o[i] as num).toDouble(),
        high: (h[i] as num).toDouble(),
        low: (l[i] as num).toDouble(),
        close: (c[i] as num).toDouble(),
      ),
    );
  }
  return out;
}

double _r(double v) => double.parse(v.toStringAsFixed(2));

Future<bool> build(Recipe r) async {
  stdout.write('${r.id.padRight(26)} ${r.symbol.padRight(8)} ');
  final List<Candle> candles;
  try {
    candles = await fetchDaily(r);
  } on Object catch (e) {
    stdout.writeln('SKIPPED — $e');
    return false;
  }

  if (candles.length < 80) {
    stdout.writeln('SKIPPED — only ${candles.length} candles');
    return false;
  }

  final (List<LadderRung> rungs, double step) = PauseLadder.forTarget(
    candles,
    r.targetPausePoints,
    minFromPeak: r.minFromPeak,
  );
  if (rungs.length < 3) {
    stdout.writeln('SKIPPED — only ${rungs.length} decision moments');
    return false;
  }

  double peak = candles.first.close;
  double worst = 0;
  for (final Candle c in candles) {
    if (c.close > peak) peak = c.close;
    final double dd = 1 - c.close / peak;
    if (dd > worst) worst = dd;
  }

  final Map<String, dynamic> level = <String, dynamic>{
    'id': r.id,
    'real_asset_name': r.assetName,
    'asset_class': r.assetClass,
    'starting_balance': 100000,
    'source': 'Yahoo Finance chart API, ${r.symbol}, daily',
    'licence': 'unverified',
    'generated_by': 'tool/import_yahoo_level.dart',
    'candles': <Map<String, dynamic>>[
      for (final Candle c in candles)
        <String, dynamic>{
          'date': c.dateKey,
          'open': _r(c.open),
          'high': _r(c.high),
          'low': _r(c.low),
          'close': _r(c.close),
        },
    ],
  };

  final List<Map<String, dynamic>> pausePoints = <Map<String, dynamic>>[];
  for (final LadderRung rung in rungs) {
    final LadderVerdict v = PauseLadder.verdictAt(candles, rung.index);
    final Candle here = candles[rung.index];
    final Candle pk = candles[rung.peakIndex];
    final String pct = (rung.fromPeak * 100).toStringAsFixed(0);

    pausePoints.add(<String, dynamic>{
      'trigger_date': here.dateKey,
      'flash_treatment':
          rung.fromPeak >= 0.20 ? 'red_flash_hard' : 'amber_flash_soft',
      'optimal_action': v.action.wireName,
      'reveal_headline': 'Down $pct% from the ${pk.dateKey} high of '
          '${pk.close.toStringAsFixed(0)}, at '
          '${here.close.toStringAsFixed(0)}. ${v.rationale}'
          '${v.ambiguous ? ' The data does not support a clean "right" answer '
              'here.' : ''}',
      'derived': <String, dynamic>{
        'peak_date': pk.dateKey,
        'peak_close': _r(pk.close),
        'close': _r(here.close),
        'from_peak_pct': double.parse(pct),
        'ambiguous': v.ambiguous,
      },
    });
  }

  final Map<String, dynamic> script = <String, dynamic>{
    'id': r.id,
    'generated_by': 'tool/import_yahoo_level.dart',
    'derivation': 'Pause points form a ladder: the script asks again each '
        'time price falls a further ${(step * 100).toStringAsFixed(1)}% below '
        'the last time it asked, while at least '
        '${(r.minFromPeak * 100).toStringAsFixed(1)}% under the running peak. '
        'optimal_action is computed from what the series did next; moments '
        'with under 20 trading days remaining are marked ambiguous.',
    'pause_points': pausePoints,
  };

  const JsonEncoder enc = JsonEncoder.withIndent('  ');
  File('data/simulator_levels/${r.id}.json').writeAsStringSync(
    enc.convert(level),
  );
  File('data/simulator_levels/${r.id}_script.json').writeAsStringSync(
    enc.convert(script),
  );

  final int ambiguous = pausePoints
      .where(
        (Map<String, dynamic> p) =>
            (p['derived'] as Map<String, dynamic>)['ambiguous'] == true,
      )
      .length;

  stdout.writeln(
    'OK  ${candles.length.toString().padLeft(4)} candles  '
    '${candles.first.dateKey}->${candles.last.dateKey}  '
    'dd=${(worst * 100).toStringAsFixed(0).padLeft(2)}%  '
    '${pausePoints.length} moments'
    '${ambiguous > 0 ? ' ($ambiguous ambiguous)' : ''}',
  );
  return true;
}

Future<void> main(List<String> args) async {
  final List<Recipe> todo;
  if (args.contains('--all')) {
    todo = recipes;
  } else if (args.isNotEmpty) {
    todo = recipes.where((Recipe r) => r.id == args.first).toList();
    if (todo.isEmpty) {
      stderr.writeln('unknown level: ${args.first}');
      stderr.writeln('known: ${recipes.map((Recipe r) => r.id).join(', ')}');
      exitCode = 64;
      return;
    }
  } else {
    stderr.writeln('usage: dart run tool/import_yahoo_level.dart '
        '<level_id> | --all');
    exitCode = 64;
    return;
  }

  int built = 0;
  for (final Recipe r in todo) {
    if (await build(r)) built++;
    // Be a good citizen with a public endpoint.
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  stdout
    ..writeln('')
    ..writeln('built $built/${todo.length}')
    ..writeln('')
    ..writeln('Levels are marked "licence": "unverified". Yahoo does not '
        'permit redistribution and index levels are the provider\'s IP — '
        'these are playable for development and demo, NOT cleared to ship.');
}
