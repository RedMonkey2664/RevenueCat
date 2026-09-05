import 'package:flutter/foundation.dart';

import '../../simulator/engine/candle_model.dart';
import 'chart_types.dart';

/// A user-drawn annotation.
///
/// Anchored to a **timestamp and a price**, never to a bar index or a pixel.
/// An index anchor breaks the moment the timeframe changes (bar 40 on the
/// daily is a different day on the weekly) and a pixel anchor breaks on the
/// first pan. Time and price are the only two things that stay true.
@immutable
class ChartDrawing {
  const ChartDrawing({
    required this.id,
    required this.tool,
    required this.time1,
    required this.price1,
    this.time2,
    this.price2,
  });

  final String id;

  /// One of [ChartTool]'s drawing tools. [ChartTool.cursor] never reaches
  /// here.
  final ChartTool tool;

  final DateTime time1;
  final double price1;

  /// Second anchor. Null for [ChartTool.horizontalLine], which spans the
  /// whole plot at one price.
  final DateTime? time2;
  final double? price2;

  bool get isTwoPoint => time2 != null && price2 != null;

  ChartDrawing withSecondPoint(DateTime t, double p) =>
      ChartDrawing(
        id: id,
        tool: tool,
        time1: time1,
        price1: price1,
        time2: t,
        price2: p,
      );

  /// Human-readable summary for the drawings list.
  String get summary => switch (tool) {
        ChartTool.horizontalLine => 'Price line',
        ChartTool.trendline => 'Trendline',
        ChartTool.rectangle => 'Rectangle',
        ChartTool.cursor => 'Cursor',
      };

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'tool': tool.name,
        't1': time1.toIso8601String(),
        'p1': price1,
        if (time2 != null) 't2': time2!.toIso8601String(),
        if (price2 != null) 'p2': price2,
      };

  factory ChartDrawing.fromJson(Map<String, dynamic> json) {
    return ChartDrawing(
      id: json['id'] as String,
      tool: ChartTool.values.firstWhere(
        (ChartTool t) => t.name == json['tool'],
        orElse: () => ChartTool.trendline,
      ),
      time1: DateTime.parse(json['t1'] as String),
      price1: (json['p1'] as num).toDouble(),
      time2: json['t2'] == null
          ? null
          : DateTime.parse(json['t2'] as String),
      price2: (json['p2'] as num?)?.toDouble(),
    );
  }
}

/// Resolves drawing timestamps back to positions on the current series.
abstract final class DrawingAnchor {
  /// Fractional bar index for [time] against [bars].
  ///
  /// Interpolates between the two bracketing bars so a trendline endpoint
  /// drawn on the 1H chart does not visibly snap when the user switches to
  /// the daily. Extrapolates beyond either end so a drawing anchored outside
  /// the loaded range still points the right way instead of clamping onto the
  /// edge bar and going flat.
  static double indexForTime(List<Candle> bars, DateTime time) {
    if (bars.isEmpty) return 0;

    final int ms = time.millisecondsSinceEpoch;
    if (ms <= bars.first.date.millisecondsSinceEpoch) {
      return _extrapolate(bars, ms, atStart: true);
    }
    if (ms >= bars.last.date.millisecondsSinceEpoch) {
      return _extrapolate(bars, ms, atStart: false);
    }

    int lo = 0;
    int hi = bars.length - 1;
    while (hi - lo > 1) {
      final int mid = (lo + hi) ~/ 2;
      if (bars[mid].date.millisecondsSinceEpoch <= ms) {
        lo = mid;
      } else {
        hi = mid;
      }
    }

    final int a = bars[lo].date.millisecondsSinceEpoch;
    final int b = bars[hi].date.millisecondsSinceEpoch;
    if (b == a) return lo.toDouble();
    return lo + (ms - a) / (b - a);
  }

  static double _extrapolate(
    List<Candle> bars,
    int ms, {
    required bool atStart,
  }) {
    if (bars.length < 2) return atStart ? 0 : (bars.length - 1).toDouble();

    final int i = atStart ? 0 : bars.length - 1;
    final int j = atStart ? 1 : bars.length - 2;
    final int ti = bars[i].date.millisecondsSinceEpoch;
    final int tj = bars[j].date.millisecondsSinceEpoch;
    final int step = (ti - tj).abs();
    if (step == 0) return i.toDouble();

    final double barsAway = (ms - ti) / step;
    return i + barsAway;
  }

  /// The timestamp a fractional bar index corresponds to, used when a new
  /// drawing is committed.
  static DateTime timeForIndex(List<Candle> bars, double index) {
    if (bars.isEmpty) return DateTime.now().toUtc();

    final int lo = index.floor().clamp(0, bars.length - 1);
    final int hi = index.ceil().clamp(0, bars.length - 1);
    if (lo == hi) {
      // Off the end: step forward by the series' own cadence rather than
      // pinning every out-of-range drawing to the last bar's timestamp.
      if (index > bars.length - 1 && bars.length >= 2) {
        final int step = bars.last.date
            .difference(bars[bars.length - 2].date)
            .inMilliseconds;
        final double extra = index - (bars.length - 1);
        return DateTime.fromMillisecondsSinceEpoch(
          bars.last.date.millisecondsSinceEpoch + (step * extra).round(),
          isUtc: true,
        );
      }
      return bars[lo].date;
    }

    final int a = bars[lo].date.millisecondsSinceEpoch;
    final int b = bars[hi].date.millisecondsSinceEpoch;
    return DateTime.fromMillisecondsSinceEpoch(
      (a + (b - a) * (index - lo)).round(),
      isUtc: true,
    );
  }
}
