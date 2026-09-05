import '../../simulator/engine/candle_model.dart';
import 'chart_types.dart';

/// Series transforms the chart applies before painting.
///
/// Kept as free functions over [Candle] rather than a second bar type: the
/// Simulator, Live Markets and Custom Simulation all speak [Candle] already,
/// and a parallel model would mean two definitions of "close" to keep in sync.
abstract final class ChartSeries {
  /// Folds [bars] at [from] into buckets at [to].
  ///
  /// Returns [bars] unchanged when the two intervals match. Throws when the
  /// combination does not tile cleanly — callers check
  /// [BarInterval.canAggregateTo] first and refetch instead.
  ///
  /// Bucket OHLC is the standard fold: first open, max high, min low, last
  /// close, summed volume. The bucket's date is the bucket *start*, so a
  /// weekly bar is dated its Monday — the convention every charting package
  /// uses, and the one that keeps the x-axis monotonic.
  static List<Candle> aggregate(
    List<Candle> bars, {
    required BarInterval from,
    required BarInterval to,
  }) {
    if (from == to) return bars;
    if (!from.canAggregateTo(to)) {
      throw ArgumentError(
        '${from.label} bars cannot be folded into ${to.label} buckets',
      );
    }
    if (bars.isEmpty) return const <Candle>[];

    final List<Candle> out = <Candle>[];

    DateTime bucket = to.bucketStart(bars.first.date);
    double open = bars.first.open;
    double high = bars.first.high;
    double low = bars.first.low;
    double close = bars.first.close;
    double? volume = bars.first.volume;

    for (int i = 1; i < bars.length; i++) {
      final Candle b = bars[i];
      final DateTime next = to.bucketStart(b.date);

      if (next != bucket) {
        out.add(
          Candle(
            date: bucket,
            open: open,
            high: high,
            low: low,
            close: close,
            volume: volume,
          ),
        );
        bucket = next;
        open = b.open;
        high = b.high;
        low = b.low;
        close = b.close;
        volume = b.volume;
        continue;
      }

      if (b.high > high) high = b.high;
      if (b.low < low) low = b.low;
      close = b.close;
      if (b.volume != null) volume = (volume ?? 0) + b.volume!;
    }

    out.add(
      Candle(
        date: bucket,
        open: open,
        high: high,
        low: low,
        close: close,
        volume: volume,
      ),
    );

    return out;
  }

  /// Heikin-Ashi transform.
  ///
  ///   haClose = (o + h + l + c) / 4
  ///   haOpen  = (previous haOpen + previous haClose) / 2, seeded (o + c) / 2
  ///   haHigh  = max(h, haOpen, haClose)
  ///   haLow   = min(l, haOpen, haClose)
  ///
  /// The result is a smoothed *derived* series, not real OHLC — so the
  /// crosshair readout and the trade panel always read the raw bars, never
  /// these. Quoting a Heikin-Ashi close as a price you could have traded at
  /// would be presenting a computed number as a market fact.
  static List<Candle> heikinAshi(List<Candle> bars) {
    if (bars.isEmpty) return const <Candle>[];

    final List<Candle> out = <Candle>[];
    double haOpen = (bars.first.open + bars.first.close) / 2;

    for (final Candle b in bars) {
      final double haClose = (b.open + b.high + b.low + b.close) / 4;
      final double haHigh =
          <double>[b.high, haOpen, haClose].reduce((double a, double c) => a > c ? a : c);
      final double haLow =
          <double>[b.low, haOpen, haClose].reduce((double a, double c) => a < c ? a : c);

      out.add(
        Candle(
          date: b.date,
          open: haOpen,
          high: haHigh,
          low: haLow,
          close: haClose,
          volume: b.volume,
        ),
      );

      haOpen = (haOpen + haClose) / 2;
    }

    return out;
  }

  /// The bars actually painted for [type], given the raw series.
  static List<Candle> forType(List<Candle> bars, ChartType type) =>
      type == ChartType.heikinAshi ? heikinAshi(bars) : bars;
}
