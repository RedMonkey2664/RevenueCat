import '../../../core/market/bar_interval.dart';
import '../../../core/market/candle.dart';
import '../../../core/market/instrument.dart';
import '../engine/level_model.dart';
import '../engine/pause_ladder.dart';
import '../engine/script_event_model.dart';

/// Turns a fetched price window into a playable run.
///
/// Deliberately produces the same [SimulationLevel] the campaign and Endless
/// modes use, so the engine, the scoring and the debrief cannot tell a custom
/// simulation apart from a handcrafted level. That is the ENGINE.md
/// non-negotiable: levels are data, never new engine code.
///
/// The one difference is [SimulationLevel.revealFromStart] — the player chose
/// the instrument and the dates, so there is nothing for blind mode to hide.
abstract final class CustomSimBuilder {
  /// The engine needs enough bars to be worth playing and enough lookahead
  /// for a verdict to mean anything (see [PauseLadder.minLookahead]).
  static const int minBars = 40;

  /// Same virtual capital as every other run, so Discipline Scores and P&L
  /// stay comparable across modes.
  static const double startingBalance = 100000;

  static SimulationLevel build({
    required Instrument instrument,
    required List<Candle> candles,
    required BarInterval interval,
    required DateTime from,
    required DateTime to,
  }) {
    if (candles.length < minBars) {
      throw CustomSimException(
        'That range only has ${candles.length} bars. Pick a longer window '
        'or a finer timeframe — a run needs at least $minBars.',
      );
    }

    final List<PausePoint> pausePoints = PauseLadder.pausePointsFor(
      candles,
      // Scaled to the window: the campaign's target of 12 is tuned for a
      // multi-month crash, and forcing 12 decision points into a three-week
      // range would ask about noise.
      target: _targetPausePoints(candles.length),
    );

    return SimulationLevel(
      id: 'custom_${instrument.id}_${interval.label}_'
          '${_key(from)}_${_key(to)}',
      realAssetName: instrument.name,
      startingBalance: startingBalance,
      candles: candles,
      pausePoints: pausePoints,
      revealFromStart: true,
      description: '${instrument.ticker} · ${interval.longLabel} bars · '
          '${_key(from)} to ${_key(to)}',
    );
  }

  /// Roughly one decision moment per 12 bars, held between 4 and 14.
  static int _targetPausePoints(int barCount) {
    final int scaled = (barCount / 12).round();
    return scaled.clamp(4, 14);
  }

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// A custom simulation that cannot be built from what the user asked for.
class CustomSimException implements Exception {
  const CustomSimException(this.message);

  final String message;

  @override
  String toString() => message;
}
