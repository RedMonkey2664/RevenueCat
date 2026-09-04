import 'package:flutter/foundation.dart';

import 'candle_model.dart';

/// A peak-to-trough decline in a level's price series.
@immutable
class DrawdownEpisode {
  const DrawdownEpisode({
    required this.peakIndex,
    required this.troughIndex,
    required this.depth,
    this.recoveryIndex,
  });

  /// Index of the high the decline started from.
  final int peakIndex;

  /// Index of the lowest close before recovery (or before the data ends).
  final int troughIndex;

  /// Decline as a fraction of the peak, e.g. 0.32 for a 32% fall.
  final double depth;

  /// Index where price first closed back at or above the peak. Null when the
  /// series ended still under water.
  final int? recoveryIndex;

  bool get recovered => recoveryIndex != null;

  double get depthPercent => depth * 100;
}

/// Finds the significant declines in a price series.
///
/// This is the objective backbone of advanced mode's Discipline Score. Free
/// trading has no scripted `optimal_action` to grade against, so instead of
/// inventing one, the score asks the same behavioural question the beginner
/// mode asks — did you cut your position while it was falling? — at moments
/// the data itself identifies.
///
/// The rule, stated plainly so it is auditable rather than a black box:
///
/// 1. Walk the closes, tracking the running peak.
/// 2. While price is below that peak, track the lowest close (the trough).
/// 3. When price closes back at or above the peak, the episode ends and
///    recovery is recorded; a new peak starts from there.
/// 4. An episode counts only if the peak-to-trough decline is at least
///    [minDepth]. Shallow wobbles are noise, not tests of nerve.
/// 5. A decline still under water when the data ends is kept, with a null
///    recovery index.
///
/// Episodes never overlap, so each one is scored exactly once.
///
/// The same rule is the natural basis for Endless mode's auto-detected pause
/// points (ENGINE.md §6) — deliberately one implementation, not two.
abstract final class DrawdownDetector {
  /// Declines shallower than this are ignored.
  ///
  /// DECISION(somi): 10% is my choice, not a spec value. It is the single
  /// knob controlling how many moments advanced mode grades — raise it and
  /// only real crashes count, lower it and ordinary dips start being graded.
  static const double defaultMinDepth = 0.10;

  static List<DrawdownEpisode> detect(
    List<Candle> candles, {
    double minDepth = defaultMinDepth,
  }) {
    if (candles.length < 2) return const <DrawdownEpisode>[];

    final List<DrawdownEpisode> episodes = <DrawdownEpisode>[];

    int peakIndex = 0;
    double peak = candles.first.close;
    int troughIndex = 0;
    double trough = candles.first.close;
    bool underWater = false;

    for (int i = 1; i < candles.length; i++) {
      final double close = candles[i].close;

      if (close >= peak) {
        if (underWater) {
          final double depth = (peak - trough) / peak;
          if (depth >= minDepth) {
            episodes.add(
              DrawdownEpisode(
                peakIndex: peakIndex,
                troughIndex: troughIndex,
                depth: depth,
                recoveryIndex: i,
              ),
            );
          }
        }
        peak = close;
        peakIndex = i;
        trough = close;
        troughIndex = i;
        underWater = false;
      } else {
        underWater = true;
        if (close < trough) {
          trough = close;
          troughIndex = i;
        }
      }
    }

    if (underWater) {
      final double depth = (peak - trough) / peak;
      if (depth >= minDepth) {
        episodes.add(
          DrawdownEpisode(
            peakIndex: peakIndex,
            troughIndex: troughIndex,
            depth: depth,
          ),
        );
      }
    }

    return List<DrawdownEpisode>.unmodifiable(episodes);
  }
}
