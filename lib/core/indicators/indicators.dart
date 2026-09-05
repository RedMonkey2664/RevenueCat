/// Technical indicators, shared by the Simulator and the pro chart.
///
/// Lives in `core/` rather than under `features/simulator/` because the chart
/// is now shared infrastructure (Simulator, Live Markets, Custom Simulation)
/// and ARCHITECTURE.md keeps feature folders from importing each other.
/// `features/simulator/engine/indicators.dart` re-exports this file, so the
/// engine's existing imports and tests are unaffected.
///
/// Every function returns a list aligned index-for-index with its input, with
/// nulls before the window is full. Drawing a value the data cannot support
/// yet is a lie the chart would render as fact.
library;

import 'dart:math' as math;

/// Simple moving average over [period] closes.
List<double?> simpleMovingAverage(List<double> closes, int period) {
  if (period <= 0) {
    throw ArgumentError.value(period, 'period', 'must be positive');
  }

  final List<double?> out = List<double?>.filled(closes.length, null);
  double sum = 0;

  for (int i = 0; i < closes.length; i++) {
    sum += closes[i];
    if (i >= period) sum -= closes[i - period];
    if (i >= period - 1) out[i] = sum / period;
  }

  return out;
}

/// Exponential moving average over [period] closes.
///
/// Seeded with the simple average of the first [period] values — the standard
/// definition, and the one that makes EMA(20) comparable to SMA(20) on the
/// same chart rather than starting from an arbitrary first close.
List<double?> exponentialMovingAverage(List<double> closes, int period) {
  if (period <= 0) {
    throw ArgumentError.value(period, 'period', 'must be positive');
  }

  final List<double?> out = List<double?>.filled(closes.length, null);
  if (closes.length < period) return out;

  double seed = 0;
  for (int i = 0; i < period; i++) {
    seed += closes[i];
  }
  double ema = seed / period;
  out[period - 1] = ema;

  final double k = 2 / (period + 1);
  for (int i = period; i < closes.length; i++) {
    ema = closes[i] * k + ema * (1 - k);
    out[i] = ema;
  }

  return out;
}

/// Relative Strength Index using Wilder's smoothing, the standard definition.
///
/// Aligned index-for-index with [closes]; null until enough history exists.
/// Values are always within 0..100.
List<double?> relativeStrengthIndex(List<double> closes, int period) {
  if (period <= 0) {
    throw ArgumentError.value(period, 'period', 'must be positive');
  }

  final List<double?> out = List<double?>.filled(closes.length, null);
  if (closes.length <= period) return out;

  double gainSum = 0;
  double lossSum = 0;

  // Seed: the simple average of the first `period` changes.
  for (int i = 1; i <= period; i++) {
    final double change = closes[i] - closes[i - 1];
    if (change >= 0) {
      gainSum += change;
    } else {
      lossSum -= change;
    }
  }

  double avgGain = gainSum / period;
  double avgLoss = lossSum / period;
  out[period] = _rsiFrom(avgGain, avgLoss);

  for (int i = period + 1; i < closes.length; i++) {
    final double change = closes[i] - closes[i - 1];
    final double gain = change > 0 ? change : 0;
    final double loss = change < 0 ? -change : 0;

    // Wilder's smoothing, not a plain rolling mean.
    avgGain = (avgGain * (period - 1) + gain) / period;
    avgLoss = (avgLoss * (period - 1) + loss) / period;
    out[i] = _rsiFrom(avgGain, avgLoss);
  }

  return out;
}

double _rsiFrom(double avgGain, double avgLoss) {
  // No downside in the window: RSI is pinned at 100 by definition rather than
  // dividing by zero.
  if (avgLoss == 0) return avgGain == 0 ? 50 : 100;
  final double rs = avgGain / avgLoss;
  return 100 - 100 / (1 + rs);
}

/// The three lines of a Bollinger Band set.
class BollingerBands {
  const BollingerBands({
    required this.upper,
    required this.middle,
    required this.lower,
  });

  final List<double?> upper;

  /// The SMA the bands are measured from.
  final List<double?> middle;

  final List<double?> lower;
}

/// Bollinger Bands: an SMA with a band [stdDevs] population standard
/// deviations either side.
///
/// Population (÷n), not sample (÷n−1) — that is what every charting package
/// uses for Bollinger, so matching it keeps our numbers comparable to what a
/// user sees elsewhere.
BollingerBands bollingerBands(
  List<double> closes,
  int period, {
  double stdDevs = 2,
}) {
  if (period <= 0) {
    throw ArgumentError.value(period, 'period', 'must be positive');
  }

  final List<double?> middle = simpleMovingAverage(closes, period);
  final List<double?> upper = List<double?>.filled(closes.length, null);
  final List<double?> lower = List<double?>.filled(closes.length, null);

  for (int i = period - 1; i < closes.length; i++) {
    final double mean = middle[i]!;
    double sumSq = 0;
    for (int j = i - period + 1; j <= i; j++) {
      final double d = closes[j] - mean;
      sumSq += d * d;
    }
    final double sd = math.sqrt(sumSq / period);
    upper[i] = mean + sd * stdDevs;
    lower[i] = mean - sd * stdDevs;
  }

  return BollingerBands(upper: upper, middle: middle, lower: lower);
}

/// MACD's three series.
class MacdResult {
  const MacdResult({
    required this.macd,
    required this.signal,
    required this.histogram,
  });

  /// Fast EMA − slow EMA.
  final List<double?> macd;

  /// EMA of [macd].
  final List<double?> signal;

  /// [macd] − [signal].
  final List<double?> histogram;
}

/// MACD (12, 26, 9 by default).
///
/// The signal line is an EMA *of the MACD line*, which only exists from the
/// slow period onwards — so it is computed over the compacted MACD values and
/// mapped back to the original indices, rather than being fed a list with
/// nulls in it.
MacdResult macd(
  List<double> closes, {
  int fastPeriod = 12,
  int slowPeriod = 26,
  int signalPeriod = 9,
}) {
  final List<double?> fast = exponentialMovingAverage(closes, fastPeriod);
  final List<double?> slow = exponentialMovingAverage(closes, slowPeriod);

  final List<double?> line = List<double?>.filled(closes.length, null);
  final List<double> compact = <double>[];
  final List<int> compactIndex = <int>[];

  for (int i = 0; i < closes.length; i++) {
    final double? f = fast[i];
    final double? s = slow[i];
    if (f == null || s == null) continue;
    final double v = f - s;
    line[i] = v;
    compact.add(v);
    compactIndex.add(i);
  }

  final List<double?> compactSignal =
      exponentialMovingAverage(compact, signalPeriod);

  final List<double?> signal = List<double?>.filled(closes.length, null);
  final List<double?> histogram = List<double?>.filled(closes.length, null);

  for (int i = 0; i < compactIndex.length; i++) {
    final double? s = compactSignal[i];
    if (s == null) continue;
    final int at = compactIndex[i];
    signal[at] = s;
    histogram[at] = line[at]! - s;
  }

  return MacdResult(macd: line, signal: signal, histogram: histogram);
}
