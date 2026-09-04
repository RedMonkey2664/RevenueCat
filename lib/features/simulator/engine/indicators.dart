/// The two real indicators (DESIGN.md, ENGINE.md §7).
///
/// Everything else on the console — MACD, Bollinger, Volume Profile — is
/// deliberately inert chrome. These two are computed properly because the
/// chart actually draws them.
library;

/// Simple moving average over [period] closes.
///
/// Returns a list aligned index-for-index with [closes]; entries before the
/// window is full are null so the chart can start the line where the data
/// genuinely begins rather than drawing a misleading ramp.
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
