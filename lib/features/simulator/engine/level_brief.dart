import 'package:meta/meta.dart';

import 'candle_model.dart';
import 'level_model.dart';

/// A pre-play brief that tells the player what they are walking into without
/// telling them *which* crash it is.
///
/// Blind mode (ENGINE.md §3) forbids naming the asset or the era before the
/// Debrief — otherwise a campaign level is a memory quiz, not a test. But
/// "here is an unlabelled chart, good luck" is a poor brief. So everything
/// here is derived from the series and deliberately identity-free: how long
/// it runs, how many decisions it will ask for, how rough it gets.
///
/// The real event story lives in [SimulationLevel.description] and is shown
/// only at the Debrief.
@immutable
class LevelBrief {
  const LevelBrief({
    required this.days,
    required this.moments,
    required this.deepestDrawdown,
    required this.severity,
  });

  factory LevelBrief.of(SimulationLevel level) {
    double peak = level.candles.first.close;
    double worst = 0;
    for (final Candle c in level.candles) {
      if (c.close > peak) peak = c.close;
      final double dd = 1 - c.close / peak;
      if (dd > worst) worst = dd;
    }

    return LevelBrief(
      days: level.candles.length,
      moments: level.pausePoints.length,
      deepestDrawdown: worst,
      severity: BriefSeverity.forDrawdown(worst),
    );
  }

  /// Trading days in the window. Relative, so it reveals no dates.
  final int days;

  final int moments;

  /// Worst peak-to-trough fall in the window, as a fraction.
  final double deepestDrawdown;

  final BriefSeverity severity;

  /// Roughly how long the window runs, in months, for human phrasing.
  int get approxMonths => (days / 21).round();

  /// One line, safe to show before play.
  String get headline {
    final int m = approxMonths;
    final String span = m <= 1 ? 'About a month' : 'About $m months';
    return '$span of daily candles, and $moments '
        '${moments == 1 ? 'decision' : 'decisions'} to make.';
  }

  /// A second line that sets expectations without naming anything.
  String get body => severity.blurb;
}

/// How rough the window gets. Bands, not exact figures — an exact drawdown
/// percentage up front would narrow the guess too far.
enum BriefSeverity {
  mild(
    'MILD',
    'It wobbles rather than collapses. The temptation here is to act on '
        'noise.',
  ),
  significant(
    'SIGNIFICANT',
    'A real fall, deep enough to hurt and shallow enough to argue about.',
  ),
  severe(
    'SEVERE',
    'This one falls hard, and more than once. Expect rallies that look like '
        'the bottom and are not.',
  ),
  historic(
    'HISTORIC',
    'One of the worst declines in this market\'s history. Holding through it '
        'was extremely difficult, and so was getting back in.',
  );

  const BriefSeverity(this.label, this.blurb);

  final String label;
  final String blurb;

  static BriefSeverity forDrawdown(double drawdown) {
    if (drawdown >= 0.50) return BriefSeverity.historic;
    if (drawdown >= 0.25) return BriefSeverity.severe;
    if (drawdown >= 0.12) return BriefSeverity.significant;
    return BriefSeverity.mild;
  }
}
