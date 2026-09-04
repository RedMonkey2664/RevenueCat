import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../campaign/level_repository.dart' show AssetClass;
import 'candle_model.dart';
import 'level_model.dart';
import 'pause_ladder.dart';

/// A bundled long-run daily series for one market (LEVELS.md).
///
/// One pool per market, reused for every generated window — far lighter than
/// curating a dataset per run.
@immutable
class HistoryPool {
  const HistoryPool({
    required this.assetClass,
    required this.assetName,
    required this.source,
    required this.candles,
  });

  factory HistoryPool.fromJson(Map<String, dynamic> json) {
    return HistoryPool(
      assetClass: AssetClass.fromWire(json['asset_class'] as String),
      assetName: json['real_asset_name'] as String,
      source: json['source'] as String? ?? 'unknown',
      candles: (json['candles'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(Candle.fromJson)
          .toList(growable: false),
    );
  }

  final AssetClass assetClass;
  final String assetName;

  /// Where the series came from, carried through to the debrief so an Endless
  /// run is as traceable as a campaign level.
  final String source;

  final List<Candle> candles;
}

/// Generates a random playable window from a bundled history pool
/// (ENGINE.md §6).
///
/// This is the one piece of genuinely new logic Endless mode needs. Everything
/// else — replay, decisions, scoring, blind mode — is the same engine the
/// campaign uses, which is the point.
class EndlessGenerator {
  const EndlessGenerator({required this.pool, Random? random})
      : _random = random;

  /// Roughly six months of daily candles (ENGINE.md §6).
  static const int windowLength = 126;

  /// A window with no meaningful decline is not a test of nerve, so windows
  /// are re-drawn until one bites. Bounded so generation always terminates.
  static const double minInterestingDrawdown = 0.12;
  static const int maxAttempts = 40;

  final HistoryPool pool;
  final Random? _random;

  bool get canGenerate => pool.candles.length > windowLength + 1;

  /// Picks a window and builds a level from it.
  ///
  /// Deliberately returns the same [SimulationLevel] the campaign uses, so
  /// the level screen cannot tell the two apart.
  SimulationLevel generate() {
    if (!canGenerate) {
      throw StateError(
        'History pool for ${pool.assetClass.label} holds only '
        '${pool.candles.length} candles — need more than $windowLength.',
      );
    }

    final Random rng = _random ?? Random();
    final int maxStart = pool.candles.length - windowLength;

    List<Candle> chosen = _windowAt(rng.nextInt(maxStart));
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (_deepestDrawdown(chosen) >= minInterestingDrawdown) break;
      chosen = _windowAt(rng.nextInt(maxStart));
    }

    return SimulationLevel(
      id: 'endless_${pool.assetClass.wireName}_'
          '${chosen.first.dateKey}_${chosen.last.dateKey}',
      realAssetName: pool.assetName,
      startingBalance: 100000,
      candles: chosen,
      // Same ladder the campaign importer uses, so a crash scores identically
      // whichever mode surfaced it.
      pausePoints: PauseLadder.pausePointsFor(chosen),
    );
  }

  List<Candle> _windowAt(int start) =>
      pool.candles.sublist(start, start + windowLength);

  static double _deepestDrawdown(List<Candle> candles) {
    double peak = candles.first.close;
    double worst = 0;
    for (final Candle c in candles) {
      if (c.close > peak) peak = c.close;
      final double dd = 1 - c.close / peak;
      if (dd > worst) worst = dd;
    }
    return worst;
  }
}

/// Loads bundled history pools.
class HistoryPoolRepository {
  const HistoryPoolRepository({AssetBundle? bundle}) : _bundle = bundle;

  static const String directory = 'data/simulator_endless';

  final AssetBundle? _bundle;

  AssetBundle get _assets => _bundle ?? rootBundle;

  static String pathFor(AssetClass market) =>
      '$directory/history_pool_${market.wireName}.json';

  Future<HistoryPool> load(AssetClass market) async {
    final String raw = await _assets.loadString(pathFor(market));
    return HistoryPool.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Which markets actually have a bundled pool.
  ///
  /// Returns only what exists rather than assuming all three: equity pools
  /// are blocked on the same per-market licensing as the campaign levels, so
  /// Endless ships crypto-only until those clear.
  Future<List<AssetClass>> availableMarkets() async {
    final List<AssetClass> found = <AssetClass>[];
    for (final AssetClass m in AssetClass.values) {
      try {
        await _assets.loadString(pathFor(m));
        found.add(m);
      } on Object catch (_) {
        // No pool bundled for this market yet.
      }
    }
    return found;
  }
}

final Provider<HistoryPoolRepository> historyPoolRepositoryProvider =
    Provider<HistoryPoolRepository>(
  (Ref ref) => const HistoryPoolRepository(),
);

final FutureProvider<List<AssetClass>> endlessMarketsProvider =
    FutureProvider<List<AssetClass>>(
  (Ref ref) => ref.watch(historyPoolRepositoryProvider).availableMarkets(),
);
