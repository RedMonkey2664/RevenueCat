// Builds a campaign level from Binance's public daily candles.
//
//   dart run tool/import_binance_level.dart crypto_winter_2018
//
// Why this exists: LEVELS.md forbids inventing prices, dates or "the
// historically optimal move". So none of those are typed by hand. This script
// pulls the real OHLCV, derives the pause points from the series itself, and
// writes reveal copy whose every number is computed from the candles it just
// downloaded.
//
// The only human inputs are the window and the instrument — both recorded in
// [_recipes] below and echoed into the generated files.
//
// Source: data-api.binance.vision, the public market-data host. No key, no
// account, no date cap.
//
// TODO(licensing): Binance's terms for redistributing historical market data
// inside a shipped app still need a read. This script makes the level
// buildable; it does not clear it for release.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// A level's human-chosen inputs. Everything else is derived.
class _Recipe {
  const _Recipe({
    required this.id,
    required this.symbol,
    required this.assetName,
    required this.assetClass,
    required this.from,
    required this.to,
    required this.targetPausePoints,
  });

  final String id;
  final String symbol;

  /// Named exactly as traded. Not "Bitcoin" — the series is the Binance
  /// BTC/USDT daily close, and the debrief says so.
  final String assetName;

  final String assetClass;

  /// Includes lead-in before the crash so the run does not open mid-fall.
  final DateTime from;
  final DateTime to;

  /// Beginner mode wants a set count of moments, "usually more than 10".
  final int targetPausePoints;
}

// Not const: DateTime.utc is not a const constructor.
final Map<String, _Recipe> _recipes = <String, _Recipe>{
  'crypto_winter_2018': _Recipe(
    id: 'crypto_winter_2018',
    symbol: 'BTCUSDT',
    assetName: 'Bitcoin (BTC/USDT, Binance daily close)',
    assetClass: 'crypto',
    // Lead-in from Nov 2017 so the Dec 2017 peak is reached on screen rather
    // than being the first candle.
    from: DateTime.utc(2017, 11, 1),
    to: DateTime.utc(2018, 12, 31),
    targetPausePoints: 12,
  ),
  'crypto_bear_2022': _Recipe(
    id: 'crypto_bear_2022',
    symbol: 'BTCUSDT',
    assetName: 'Bitcoin (BTC/USDT, Binance daily close)',
    assetClass: 'crypto',
    // Lead-in from Feb 2022, through Terra/LUNA in May and FTX in November.
    from: DateTime.utc(2022, 2, 1),
    to: DateTime.utc(2022, 12, 31),
    targetPausePoints: 12,
  ),
};

class Candle {
  Candle(this.date, this.open, this.high, this.low, this.close, this.volume);

  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  String get dateKey => date.toIso8601String().split('T').first;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': dateKey,
        'open': _r(open),
        'high': _r(high),
        'low': _r(low),
        'close': _r(close),
        'volume': _r(volume),
      };

  static double _r(double v) => double.parse(v.toStringAsFixed(2));
}

Future<List<Candle>> fetchDaily(
  String symbol,
  DateTime from,
  DateTime to,
) async {
  final List<Candle> out = <Candle>[];
  int cursor = from.millisecondsSinceEpoch;
  final int end = to.millisecondsSinceEpoch;

  // Binance caps a response at 1000 candles, so page until the window is done.
  while (cursor <= end) {
    final Uri uri = Uri.https(
      'data-api.binance.vision',
      '/api/v3/klines',
      <String, String>{
        'symbol': symbol,
        'interval': '1d',
        'startTime': cursor.toString(),
        'endTime': end.toString(),
        'limit': '1000',
      },
    );

    final http.Response res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Binance returned ${res.statusCode}: ${res.body}');
    }

    final List<dynamic> rows = jsonDecode(res.body) as List<dynamic>;
    if (rows.isEmpty) break;

    for (final dynamic row in rows) {
      final List<dynamic> k = row as List<dynamic>;
      out.add(
        Candle(
          DateTime.fromMillisecondsSinceEpoch(k[0] as int, isUtc: true),
          double.parse(k[1] as String),
          double.parse(k[2] as String),
          double.parse(k[3] as String),
          double.parse(k[4] as String),
          double.parse(k[5] as String),
        ),
      );
    }

    final int last = rows.last[0] as int;
    if (last <= cursor) break;
    cursor = last + const Duration(days: 1).inMilliseconds;
  }

  return out;
}

/// One scripted decision moment: an index into the series, plus the running
/// peak it is measured against.
class Trigger {
  Trigger(this.index, this.peakIndex, this.fromPeak);

  final int index;
  final int peakIndex;

  /// Fraction below the running peak at this point, e.g. 0.42 for -42%.
  final double fromPeak;
}

/// Builds a ladder of decision moments through a decline.
///
/// The app's DrawdownDetector finds whole peak-to-trough *episodes*, which is
/// right for scoring advanced mode. It is wrong for authoring a beginner
/// script: a sustained bear market contains exactly one episode, because price
/// never makes a new high, so no threshold splits 2018 into more than a single
/// moment. Lowering the threshold does not help.
///
/// Instead this asks again every time price falls another [step] below the
/// last time it asked — which is what the year actually felt like, and what
/// makes a 12-moment beginner level a real repeated test of nerve rather than
/// one question.
///
/// A new high resets the ladder, so a recovery followed by a second leg down
/// starts asking again.
List<Trigger> buildLadder(
  List<Candle> candles,
  double step, {
  double minFromPeak = 0.08,
}) {
  final List<Trigger> out = <Trigger>[];
  double peak = candles.first.close;
  int peakIndex = 0;
  double? lastTrigger;

  for (int i = 1; i < candles.length; i++) {
    final double close = candles[i].close;
    if (close > peak) {
      peak = close;
      peakIndex = i;
      lastTrigger = null;
      continue;
    }

    final double fromPeak = 1 - close / peak;
    if (fromPeak < minFromPeak) continue;
    if (lastTrigger != null && close > lastTrigger * (1 - step)) continue;

    out.add(Trigger(i, peakIndex, fromPeak));
    lastTrigger = close;
  }

  return out;
}

/// Picks the step size whose ladder lands closest to [target] moments.
(List<Trigger>, double) ladderForTarget(List<Candle> candles, int target) {
  List<Trigger> best = buildLadder(candles, 0.10);
  double bestStep = 0.10;
  int bestDelta = (best.length - target).abs();

  for (double step = 0.03; step <= 0.30; step += 0.005) {
    final List<Trigger> found = buildLadder(candles, step);
    final int delta = (found.length - target).abs();
    if (delta < bestDelta) {
      best = found;
      bestStep = step;
      bestDelta = delta;
    }
  }

  return (best, bestStep);
}

/// The mechanical `optimal_action` rule, stated so it is auditable.
///
/// At the trigger candle, look only at what the series did afterwards:
///   • rebounded 25%+ from here          -> buy_dip
///   • ended at or above this price      -> hold
///   • fell a further 25%+ from here     -> sell
///   • anything else                     -> hold (non-panic default, and the
///                                          reveal says it was ambiguous)
///
/// Nothing here is a judgement call about what a trader "should" have felt.
({String action, String rationale, bool ambiguous}) deriveOptimalAction(
  List<Candle> candles,
  int triggerIndex,
) {
  final double triggerClose = candles[triggerIndex].close;
  final List<Candle> after = candles.sublist(triggerIndex + 1);

  // Too little future left to claim anything. Judging "buy the dip was
  // right" on a handful of candles would be an assertion the data does not
  // support, so it is declared ambiguous instead.
  if (after.length < 20) {
    return (
      action: 'hold',
      rationale: 'Only ${after.length} trading days remain in this window — '
          'too few to say what followed.',
      ambiguous: true,
    );
  }

  double futureMax = after.first.close;
  double futureMin = after.first.close;
  for (final Candle c in after) {
    if (c.close > futureMax) futureMax = c.close;
    if (c.close < futureMin) futureMin = c.close;
  }
  final double endClose = after.last.close;

  final double rebound = (futureMax / triggerClose - 1) * 100;
  final double further = (futureMin / triggerClose - 1) * 100;
  final double toEnd = (endClose / triggerClose - 1) * 100;

  if (futureMax >= triggerClose * 1.25) {
    return (
      action: 'buy_dip',
      rationale: 'Price rebounded ${rebound.toStringAsFixed(0)}% above this '
          'level later in the window.',
      ambiguous: false,
    );
  }
  if (endClose >= triggerClose) {
    return (
      action: 'hold',
      rationale: 'Price ended the window ${toEnd.toStringAsFixed(0)}% above '
          'this level.',
      ambiguous: false,
    );
  }
  if (futureMin <= triggerClose * 0.75) {
    return (
      action: 'sell',
      rationale: 'Price fell a further ${further.abs().toStringAsFixed(0)}% '
          'below this level before the window ended.',
      ambiguous: false,
    );
  }
  return (
    action: 'hold',
    rationale: 'Price drifted to ${toEnd.toStringAsFixed(0)}% from this level '
        'without a clear recovery or a further collapse.',
    ambiguous: true,
  );
}

Future<void> main(List<String> args) async {
  if (args.isEmpty || !_recipes.containsKey(args.first)) {
    stderr.writeln('usage: dart run tool/import_binance_level.dart <level_id>');
    stderr.writeln('known: ${_recipes.keys.join(', ')}');
    exitCode = 64;
    return;
  }

  final _Recipe r = _recipes[args.first]!;
  stdout.writeln('Fetching ${r.symbol} ${r.from.toIso8601String()} '
      '-> ${r.to.toIso8601String()} ...');

  final List<Candle> candles = await fetchDaily(r.symbol, r.from, r.to);
  if (candles.length < 60) {
    throw Exception('Only ${candles.length} candles — refusing to build.');
  }

  final (List<Trigger> triggers, double step) =
      ladderForTarget(candles, r.targetPausePoints);

  double peakClose = candles.first.close;
  double troughClose = candles.first.close;
  for (final Candle c in candles) {
    if (c.close > peakClose) peakClose = c.close;
    if (c.close < troughClose) troughClose = c.close;
  }

  // --- level file -----------------------------------------------------------
  final Map<String, dynamic> level = <String, dynamic>{
    'id': r.id,
    'real_asset_name': r.assetName,
    'asset_class': r.assetClass,
    'starting_balance': 100000,
    'source': 'Binance public market data (data-api.binance.vision), '
        '${r.symbol} 1d klines',
    'generated_by': 'tool/import_binance_level.dart',
    'candles': candles.map((Candle c) => c.toJson()).toList(),
  };

  // --- script file ----------------------------------------------------------
  final List<Map<String, dynamic>> pausePoints = <Map<String, dynamic>>[];
  for (final Trigger t in triggers) {
    final Candle here = candles[t.index];
    final Candle peak = candles[t.peakIndex];
    final ({String action, String rationale, bool ambiguous}) verdict =
        deriveOptimalAction(candles, t.index);

    final String depthPct = (t.fromPeak * 100).toStringAsFixed(0);
    pausePoints.add(<String, dynamic>{
      'trigger_date': here.dateKey,
      'flash_treatment':
          t.fromPeak >= 0.20 ? 'red_flash_hard' : 'amber_flash_soft',
      'optimal_action': verdict.action,
      'reveal_headline': 'Down $depthPct% from the ${peak.dateKey} high of '
          '\$${peak.close.toStringAsFixed(0)}, trading at '
          '\$${here.close.toStringAsFixed(0)}. ${verdict.rationale}'
          '${verdict.ambiguous ? ' The data does not support a clean "right" '
              'answer here.' : ''}',
      'derived': <String, dynamic>{
        'peak_date': peak.dateKey,
        'peak_close': peak.close,
        'close': here.close,
        'from_peak_pct': double.parse(depthPct),
        'ambiguous': verdict.ambiguous,
      },
    });
  }

  final Map<String, dynamic> script = <String, dynamic>{
    'id': r.id,
    'generated_by': 'tool/import_binance_level.dart',
    'derivation': 'Pause points form a ladder: the script asks again each '
        'time price falls a further ${(step * 100).toStringAsFixed(1)}% below '
        'the last time it asked, while at least 8% under the running peak. A '
        'new high resets the ladder. optimal_action is computed from what the '
        'series did afterwards, never hand-picked; moments with fewer than 20 '
        'trading days remaining are marked ambiguous.',
    'pause_points': pausePoints,
  };

  const JsonEncoder enc = JsonEncoder.withIndent('  ');
  final Directory dir = Directory('data/simulator_levels');
  File('${dir.path}/${r.id}.json').writeAsStringSync(enc.convert(level));
  File('${dir.path}/${r.id}_script.json').writeAsStringSync(enc.convert(script));

  stdout
    ..writeln('')
    ..writeln(r.id)
    ..writeln('  candles      ${candles.length} '
        '(${candles.first.dateKey} -> ${candles.last.dateKey})')
    ..writeln('  peak close   \$${peakClose.toStringAsFixed(2)}')
    ..writeln('  trough close \$${troughClose.toStringAsFixed(2)}')
    ..writeln('  max drawdown '
        '${((1 - troughClose / peakClose) * 100).toStringAsFixed(1)}%')
    ..writeln('  pause points ${pausePoints.length} '
        '(ladder step ${(step * 100).toStringAsFixed(1)}%)');

  for (final Map<String, dynamic> p in pausePoints) {
    final Map<String, dynamic> d = p['derived'] as Map<String, dynamic>;
    stdout.writeln('    ${p['trigger_date']}  -${d['from_peak_pct']}%  '
        '-> ${p['optimal_action']}'
        '${d['ambiguous'] == true ? '  (ambiguous)' : ''}');
  }

  stdout.writeln('');
  stdout.writeln('Wrote data/simulator_levels/${r.id}.json and '
      '${r.id}_script.json');
  stdout.writeln('Set "data_status": "sourced" in level_manifest.json to '
      'make it playable.');
}
