import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// The Daily Pivot's clock. IST, fixed at UTC+5:30 with no daylight saving,
/// so "9:00" and "17:00" mean the same instant for every player whatever
/// their device's timezone — one question, one resolution, for everyone.
abstract final class PivotClock {
  static const Duration istOffset = Duration(hours: 5, minutes: 30);
  static const int openHour = 9;
  static const int closeHour = 17;

  /// The IST calendar day containing [utc], as `yyyy-mm-dd`.
  static String dayKey(DateTime utc) {
    final DateTime ist = utc.toUtc().add(istOffset);
    return '${ist.year.toString().padLeft(4, '0')}-'
        '${ist.month.toString().padLeft(2, '0')}-'
        '${ist.day.toString().padLeft(2, '0')}';
  }

  static DateTime _istMidnightUtc(String dayKey) {
    final List<int> p = dayKey.split('-').map(int.parse).toList();
    return DateTime.utc(p[0], p[1], p[2]).subtract(istOffset);
  }

  /// 09:00 IST on [dayKey], as a UTC instant.
  static DateTime openUtc(String dayKey) =>
      _istMidnightUtc(dayKey).add(const Duration(hours: openHour));

  /// 17:00 IST on [dayKey], as a UTC instant.
  static DateTime closeUtc(String dayKey) =>
      _istMidnightUtc(dayKey).add(const Duration(hours: closeHour));

  /// The previous IST day's key.
  static String previousDay(String dayKey) => PivotClock.dayKey(
    _istMidnightUtc(dayKey).subtract(const Duration(hours: 12)),
  );

  /// "7 SEP" for the header.
  static String shortDate(String dayKey) {
    const List<String> months = <String>[
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    final List<int> p = dayKey.split('-').map(int.parse).toList();
    return '${p[2]} ${months[p[1] - 1]}';
  }

  /// "09:04" in IST.
  static String istClock(DateTime utc) {
    final DateTime ist = utc.toUtc().add(istOffset);
    return '${ist.hour.toString().padLeft(2, '0')}:'
        '${ist.minute.toString().padLeft(2, '0')}';
  }
}

/// Where in the day we are.
enum PivotWindow {
  /// Before 09:00 IST — today's question does not exist yet.
  beforeOpen,

  /// 09:00–17:00 IST — voting is open.
  open,

  /// After 17:00 IST — the poll is closed and the outcome can be read.
  closed;

  static PivotWindow at(DateTime utc) {
    final String day = PivotClock.dayKey(utc);
    if (utc.isBefore(PivotClock.openUtc(day))) return PivotWindow.beforeOpen;
    if (utc.isBefore(PivotClock.closeUtc(day))) return PivotWindow.open;
    return PivotWindow.closed;
  }
}

enum PivotChoice {
  yes('YES', 'ABOVE'),
  no('NO', 'BELOW');

  const PivotChoice(this.label, this.meaning);

  final String label;
  final String meaning;

  static PivotChoice fromName(String name) =>
      PivotChoice.values.firstWhere((PivotChoice c) => c.name == name);
}

/// One day's question. The rule, stated once so it is auditable
/// (DAILY_PIVOT.md): **the strike is BTC/USDT's price at 09:00 IST** — the
/// open of Binance's 09:00 one-minute bar — and the question is whether the
/// 17:00 IST price, the close of the 16:59 bar, finishes above it.
@immutable
class PivotQuestion {
  const PivotQuestion({required this.dayKey, required this.strike});

  final String dayKey;
  final double strike;

  DateTime get openUtc => PivotClock.openUtc(dayKey);
  DateTime get closeUtc => PivotClock.closeUtc(dayKey);
}

/// A sealed vote. One per day, and it cannot be changed.
@immutable
class PivotVote {
  const PivotVote({
    required this.dayKey,
    required this.choice,
    required this.sealedAt,
    required this.strike,
  });

  factory PivotVote.fromJson(Map<String, dynamic> json) => PivotVote(
    dayKey: json['day'] as String,
    choice: PivotChoice.fromName(json['choice'] as String),
    sealedAt: DateTime.parse(json['at'] as String),
    strike: (json['strike'] as num).toDouble(),
  );

  final String dayKey;
  final PivotChoice choice;
  final DateTime sealedAt;
  final double strike;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'day': dayKey,
    'choice': choice.name,
    'at': sealedAt.toIso8601String(),
    'strike': strike,
  };
}

/// The crowd, as far as the backend can see it.
@immutable
class PivotTally {
  const PivotTally({
    required this.yes,
    required this.no,
    required this.source,
    required this.isAggregate,
  });

  final int yes;
  final int no;

  /// Where the count came from, shown on screen beside it.
  final String source;

  /// False when the count is this device only — see `LocalPivotBackend`.
  final bool isAggregate;

  int get total => yes + no;

  double get yesShare => total == 0 ? 0 : yes / total;

  /// A split is only shown once enough people have voted for it to mean
  /// anything. Below this the screen shows the low-vote variant instead of a
  /// percentage — 1 vote of 1 is "100% YES", and that is not a crowd.
  bool get isReadable => isAggregate && total >= PivotScoring.minCrowd;

  PivotChoice? get majority {
    if (!isReadable || yes == no) return null;
    return yes > no ? PivotChoice.yes : PivotChoice.no;
  }
}

/// The resolved day.
@immutable
class PivotOutcome {
  const PivotOutcome({
    required this.dayKey,
    required this.strike,
    required this.close,
  });

  factory PivotOutcome.fromJson(Map<String, dynamic> json) => PivotOutcome(
    dayKey: json['day'] as String,
    strike: (json['strike'] as num).toDouble(),
    close: (json['close'] as num).toDouble(),
  );

  final String dayKey;
  final double strike;

  /// BTC/USDT at 17:00 IST.
  final double close;

  PivotChoice get winner => close > strike ? PivotChoice.yes : PivotChoice.no;

  double get changePercent => (close / strike - 1) * 100;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'day': dayKey,
    'strike': strike,
    'close': close,
  };
}

/// What a day's call earned, line by line.
@immutable
class PivotAward {
  const PivotAward({
    required this.base,
    required this.contrarianBonus,
    required this.multiplier,
  });

  static const PivotAward none = PivotAward(
    base: 0,
    contrarianBonus: 0,
    multiplier: 1,
  );

  final int base;
  final int contrarianBonus;
  final double multiplier;

  int get total => ((base + contrarianBonus) * multiplier).round();
}

/// The points rules. Discipline Points only — never money, never
/// withdrawable (CLAUDE.md, DAILY_PIVOT.md).
abstract final class PivotScoring {
  /// A correct call.
  static const int base = 10;

  /// A correct call against the majority pays this multiple of [base]: the
  /// point is conviction, not just being right.
  static const double contrarianMultiple = 2.4;

  /// Streak length at which the multiplier starts to apply.
  static const int streakForMultiplier = 7;
  static const double streakMultiplier = 1.5;

  /// Votes needed before the crowd split is shown or used.
  static const int minCrowd = 250;

  static int get contrarianTotal => (base * contrarianMultiple).round();

  static PivotAward award({
    required bool correct,
    required bool contrarian,
    required int streak,
  }) {
    // Wrong: no points and no penalty. Participation is never punished.
    if (!correct) return PivotAward.none;
    return PivotAward(
      base: base,
      contrarianBonus: contrarian ? contrarianTotal - base : 0,
      multiplier: streak >= streakForMultiplier ? streakMultiplier : 1,
    );
  }

  /// Consecutive IST days with a vote, ending on [lastDay] (inclusive).
  static int streakEndingOn(String lastDay, Set<String> votedDays) {
    int n = 0;
    String day = lastDay;
    while (votedDays.contains(day)) {
      n++;
      day = PivotClock.previousDay(day);
    }
    return math.max(0, n);
  }
}
