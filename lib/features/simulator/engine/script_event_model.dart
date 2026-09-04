import 'package:meta/meta.dart';

import 'candle_model.dart';

/// The three — and only three — moves a player can make (ENGINE.md §2).
enum DecisionAction {
  hold('hold', 'Hold'),
  sell('sell', 'Sell All'),
  buyDip('buy_dip', 'Buy the Dip');

  const DecisionAction(this.wireName, this.label);

  final String wireName;
  final String label;

  static DecisionAction fromWire(String value) {
    return DecisionAction.values.firstWhere(
      (DecisionAction a) => a.wireName == value,
      orElse: () => throw FormatException('Unknown optimal_action: $value'),
    );
  }

  /// Selling into a drawdown is the panic response the whole app exists to
  /// discourage; Hold and Buy-the-Dip are both non-panic responses. Used by
  /// the Discipline Score's partial-credit rule (ENGINE.md §4).
  bool get isPanicResponse => this == DecisionAction.sell;
}

/// How the screen reacts when a pause point fires (DESIGN.md).
enum FlashTreatment {
  redFlashHard('red_flash_hard'),
  amberFlashSoft('amber_flash_soft');

  const FlashTreatment(this.wireName);

  final String wireName;

  static FlashTreatment fromWire(String value) {
    return FlashTreatment.values.firstWhere(
      (FlashTreatment f) => f.wireName == value,
      orElse: () => FlashTreatment.redFlashHard,
    );
  }
}

/// A scripted moment where playback halts and the player must decide.
///
/// Authored as data (`<level_id>_script.json`) — never as engine code.
/// [triggerIndex] is resolved from `trigger_date` at load time against the
/// level's candle array.
@immutable
class PausePoint {
  const PausePoint({
    required this.triggerIndex,
    required this.flashTreatment,
    required this.optimalAction,
    required this.revealHeadline,
  });

  final int triggerIndex;
  final FlashTreatment flashTreatment;

  /// What actually happened next, per LEVELS.md's sourcing rule. Never a
  /// judgement call invented to make the game feel good.
  final DecisionAction optimalAction;

  /// Shown at Debrief only — never during play, or blind mode leaks.
  final String revealHeadline;

  /// Builds a pause point from script JSON, resolving `trigger_date` against
  /// [candles].
  ///
  /// Throws if the date is not in the series: a script that points at a day
  /// the level's data does not contain is a data bug we want loud, not one
  /// silently clamped to a nearby candle.
  factory PausePoint.fromJson(
    Map<String, dynamic> json,
    List<Candle> candles,
  ) {
    final String triggerDate = json['trigger_date'] as String;
    final int index =
        candles.indexWhere((Candle c) => c.dateKey == triggerDate);
    if (index < 0) {
      throw FormatException(
        'Script trigger_date $triggerDate has no matching candle in the '
        'level data.',
      );
    }
    return PausePoint(
      triggerIndex: index,
      flashTreatment:
          FlashTreatment.fromWire(json['flash_treatment'] as String),
      optimalAction: DecisionAction.fromWire(json['optimal_action'] as String),
      revealHeadline: json['reveal_headline'] as String,
    );
  }
}

/// A decision the player actually made, kept for the Debrief breakdown.
@immutable
class RecordedDecision {
  const RecordedDecision({
    required this.pausePoint,
    required this.chosen,
    required this.portfolioValueAtDecision,
  });

  final PausePoint pausePoint;
  final DecisionAction chosen;
  final double portfolioValueAtDecision;

  bool get wasOptimal => chosen == pausePoint.optimalAction;
}
