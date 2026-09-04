import 'package:flutter/foundation.dart';

/// How a run is played.
///
/// Both modes use the same engine, the same level data and the same
/// behavioural question — "did you cut your position when it fell?". Only the
/// interaction differs, which is what keeps the Discipline Score comparable
/// across the two.
enum SimulationMode {
  /// Guided: playback halts at each scripted pause point and offers exactly
  /// three moves (ENGINE.md §2). The number of moments is fixed by the
  /// level's script.
  beginner(
    'Beginner',
    'Guided. Playback stops at each key moment and asks for one of three '
        'calls.',
  ),

  /// Free trading: playback never halts, and the player may buy or sell any
  /// size at any candle.
  ///
  /// NOTE(spec): CLAUDE.md's "What this app is NOT" currently rules out
  /// "manual continuous trading". Somi asked for this mode explicitly, so the
  /// code follows the request — CLAUDE.md and ENGINE.md need updating to
  /// match, or they will keep contradicting the shipped app.
  advanced(
    'Advanced',
    'Free trading. Buy or sell any size, at any moment, with no pauses.',
  );

  const SimulationMode(this.label, this.blurb);

  final String label;
  final String blurb;

  bool get isBeginner => this == SimulationMode.beginner;

  bool get isAdvanced => this == SimulationMode.advanced;
}

/// A trade executed in advanced mode.
@immutable
class Trade {
  const Trade({
    required this.candleIndex,
    required this.isBuy,
    required this.fraction,
    required this.price,
    required this.unitsDelta,
  });

  final int candleIndex;
  final bool isBuy;

  /// Fraction of available cash (buy) or of the held position (sell).
  final double fraction;

  final double price;

  /// Signed change in units held. Negative for a sell.
  final double unitsDelta;
}
