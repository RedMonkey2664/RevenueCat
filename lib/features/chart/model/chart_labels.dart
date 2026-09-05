import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'chart_types.dart';

/// How the axes and the crosshair render values.
///
/// Abstracted rather than hard-coded because blind mode (ENGINE.md §3) is not
/// a styling choice: during a Simulator run neither an absolute price nor a
/// real date may reach the screen, or the asset can be inferred from the axes
/// and the whole mode is pointless. The chart therefore never formats a value
/// itself — it asks whichever [ChartLabels] it was given.
@immutable
abstract class ChartLabels {
  const ChartLabels();

  /// Price-gutter and crosshair price text.
  String price(double value);

  /// Time-axis text for the bar at [barIndex].
  String time(DateTime date, int barIndex, BarInterval interval);

  /// Longer form for the crosshair's time readout.
  String timeDetailed(DateTime date, int barIndex, BarInterval interval);

  /// Whether real dates may be shown at all. Drives whether the time axis
  /// draws year separators.
  bool get showsRealDates;
}

/// Real prices and real dates — Live Markets, Custom Simulation, and the
/// Simulator's debrief once the reveal has happened.
class RealChartLabels extends ChartLabels {
  const RealChartLabels({this.currencySymbol = ''});

  /// Prefix for price labels, e.g. '₹' or '\$'. Empty for indices.
  final String currencySymbol;

  @override
  bool get showsRealDates => true;

  @override
  String price(double value) => '$currencySymbol${formatPrice(value)}';

  @override
  String time(DateTime date, int barIndex, BarInterval interval) {
    if (interval.isIntraday) {
      return '${_two(date.hour)}:${_two(date.minute)}';
    }
    if (interval == BarInterval.mo1) {
      return '${_months[date.month - 1]} ${_two(date.year % 100)}';
    }
    return '${date.day} ${_months[date.month - 1]}';
  }

  @override
  String timeDetailed(DateTime date, int barIndex, BarInterval interval) {
    final String d = '${date.day} ${_months[date.month - 1]} ${date.year}';
    if (!interval.isIntraday) return d;
    return '$d ${_two(date.hour)}:${_two(date.minute)}';
  }
}

/// Blind mode: a relative index and a day counter, nothing else.
///
/// Prices are rebased so the level's first bar reads 100 — the same transform
/// the previous fl_chart view used, kept so the axis reads the same way it
/// always has.
///
/// [baselinePrice] is the level's opening close, NOT the first visible bar:
/// a baseline that moved as the player panned would make the same candle show
/// two different index values.
///
/// Pair with [PriceScale.percent] so the gridlines land on round moves.
class BlindChartLabels extends ChartLabels {
  const BlindChartLabels({required this.baselinePrice});

  final double baselinePrice;

  @override
  bool get showsRealDates => false;

  /// Receives a real price and rebases it, which is what keeps the absolute
  /// number off the screen: no caller has to remember to hide it.
  @override
  String price(double value) {
    if (baselinePrice <= 0) return value.toStringAsFixed(1);
    return (value / baselinePrice * 100).toStringAsFixed(1);
  }

  @override
  String time(DateTime date, int barIndex, BarInterval interval) =>
      'D${barIndex + 1}';

  @override
  String timeDetailed(DateTime date, int barIndex, BarInterval interval) =>
      'Day ${barIndex + 1}';
}

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _two(int v) => v.toString().padLeft(2, '0');

/// Price text with a decimal count that suits the magnitude.
///
/// An index at 21,459 does not need two decimals and a token at 0.00004213
/// is destroyed by them, so precision follows the number rather than a fixed
/// setting.
String formatPrice(double value) {
  final double a = value.abs();
  if (a >= 10000) return value.toStringAsFixed(0);
  if (a >= 100) return value.toStringAsFixed(2);
  if (a >= 1) return value.toStringAsFixed(3);
  if (a >= 0.01) return value.toStringAsFixed(4);
  if (a == 0) return '0';
  return value.toStringAsFixed(8);
}

/// Compact volume, e.g. 1.2M.
String formatVolume(double value) {
  if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(1)}B';
  if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(1)}M';
  if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(1)}K';
  return value.toStringAsFixed(0);
}

/// "Nice" tick values covering [min]..[max].
///
/// The standard 1/2/2.5/5/10 ladder, so gridlines land on numbers a human
/// would have chosen (50, 100, 250) rather than on 47.3618.
List<double> niceTicks(double min, double max, {int target = 5}) {
  if (!min.isFinite || !max.isFinite || max <= min || target <= 0) {
    return const <double>[];
  }

  final double raw = (max - min) / target;
  final double magnitude = math.pow(10, (math.log(raw) / math.ln10).floor())
      .toDouble();
  final double normalized = raw / magnitude;

  final double step = (normalized <= 1
          ? 1
          : normalized <= 2
              ? 2
              : normalized <= 2.5
                  ? 2.5
                  : normalized <= 5
                      ? 5
                      : 10) *
      magnitude;

  final List<double> out = <double>[];
  double v = (min / step).ceil() * step;
  // Guard against a pathological step that would spin here.
  int guard = 0;
  while (v <= max && guard++ < 200) {
    out.add(v);
    v += step;
  }
  return out;
}
