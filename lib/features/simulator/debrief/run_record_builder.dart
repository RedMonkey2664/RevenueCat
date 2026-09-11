import 'dart:math' as math;

import '../../../core/services/run_history_service.dart';
import '../engine/candle_model.dart';
import '../engine/discipline_score.dart';
import '../engine/drawdown_detector.dart';
import '../engine/replay_controller.dart';
import '../engine/simulation_mode.dart' show Trade;

/// Turns a finished run into the plain [RunRecord] the Nerve Profile reads.
///
/// Lives with the Simulator because only the Simulator knows what a run's
/// candles and decisions mean; the profile only ever sees the samples.
abstract final class RunRecordBuilder {
  /// Falls smaller than this are noise, not a test of nerve — the same floor
  /// the advanced-mode score uses to find its drawdowns.
  static const double _minDecline = DrawdownDetector.defaultMinDepth / 2;

  static RunRecord fromRun(ReplayState state, {required String title}) {
    final List<Candle> candles = state.level.candles;
    final DisciplineScore score = state.disciplineScore;

    final List<DecisionSample> samples = state.mode.isBeginner
        ? _beginnerSamples(state, candles, score)
        : _advancedSamples(state, candles, score);

    return RunRecord(
      levelId: state.level.id,
      title: title,
      mode: state.mode.name,
      score: score.score,
      playedAt: DateTime.now(),
      samples: samples,
    );
  }

  static List<DecisionSample> _beginnerSamples(
    ReplayState state,
    List<Candle> candles,
    DisciplineScore score,
  ) {
    return <DecisionSample>[
      for (int i = 0; i < state.decisions.length; i++)
        _sampleAt(
          candles,
          state.decisions[i].pausePoint.triggerIndex,
          action: state.decisions[i].chosen.wireName,
          credit: i < score.moments.length ? score.moments[i].credit : 1,
          seconds: state.decisions[i].timeToDecide == null
              ? null
              : state.decisions[i].timeToDecide!.inMilliseconds / 1000,
        ),
    ];
  }

  /// One sample per graded drawdown: where the player first sold into it,
  /// else where they first added, else its trough (they held through).
  static List<DecisionSample> _advancedSamples(
    ReplayState state,
    List<Candle> candles,
    DisciplineScore score,
  ) {
    final List<DecisionSample> out = <DecisionSample>[];
    for (final DrawdownEpisode e in state.drawdownEpisodes) {
      final Iterable<Trade> inside = state.trades.where(
        (Trade t) =>
            t.candleIndex >= e.peakIndex && t.candleIndex <= e.troughIndex,
      );
      final Trade? firstSell = inside
          .where((Trade t) => t.unitsDelta < 0)
          .firstOrNull;
      final Trade? firstBuy = inside
          .where((Trade t) => t.unitsDelta > 0)
          .firstOrNull;

      final ScoredMoment? moment = score.moments
          .where((ScoredMoment m) => m.candleIndex == e.troughIndex)
          .firstOrNull;
      // An episode the player sat out in cash was not graded, so it is not
      // a sample either.
      if (moment == null) continue;

      final (int index, String action) = firstSell != null
          ? (firstSell.candleIndex, 'trim')
          : firstBuy != null
          ? (firstBuy.candleIndex, 'add')
          : (e.troughIndex, 'hold');
      final DecisionSample s = _sampleAt(
        candles,
        index,
        action: action,
        credit: moment.credit,
      );
      if (s.drawdown >= _minDecline || action != 'hold') out.add(s);
    }
    return out;
  }

  static DecisionSample _sampleAt(
    List<Candle> candles,
    int index, {
    required String action,
    required double credit,
    double? seconds,
  }) {
    int peakIndex = 0;
    for (int i = 0; i <= index && i < candles.length; i++) {
      if (candles[i].close > candles[peakIndex].close) peakIndex = i;
    }
    final double peak = candles[peakIndex].close;
    final double here = candles[math.min(index, candles.length - 1)].close;
    final double drawdown = peak <= 0 ? 0 : math.max(0, 1 - here / peak);
    final int days = math.max(1, index - peakIndex);

    return DecisionSample(
      action: action,
      drawdown: drawdown,
      crashSpeed: drawdown / days,
      credit: credit,
      seconds: seconds,
    );
  }
}

/// A short title for a revealed run: the manifest's "2000–2002 — The Dot-Com
/// Crash" becomes "The Dot-Com Crash".
String shortRevealTitle(String revealTitle) {
  const String sep = ' — ';
  final int at = revealTitle.indexOf(sep);
  return at < 0 ? revealTitle : revealTitle.substring(at + sep.length);
}
