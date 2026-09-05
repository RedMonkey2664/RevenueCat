/// Timeframes the app understands.
///
/// Lives in `core/` because it is shared vocabulary in two directions: it is
/// what a `MarketDataProvider` is asked to fetch, and it is what the chart
/// folds bars into locally. Which of the two happens for a given request
/// depends on the base interval the host already holds — see
/// `ChartSeries.aggregate` and [canAggregateTo].
///
/// `features/chart/model/chart_types.dart` re-exports it.
library;

enum BarInterval {
  m1('1m', '1 minute'),
  m5('5m', '5 minutes'),
  m15('15m', '15 minutes'),
  m30('30m', '30 minutes'),
  h1('1H', '1 hour'),
  h4('4H', '4 hours'),
  d1('1D', '1 day'),
  w1('1W', '1 week'),
  mo1('1M', '1 month');

  const BarInterval(this.label, this.longLabel);

  /// Toolbar text, e.g. "1D".
  final String label;

  /// Spoken form, used in accessibility labels and error copy.
  final String longLabel;

  bool get isIntraday => index <= BarInterval.h4.index;

  /// Whether bars at this interval can be folded up into [coarser].
  ///
  /// Ordering alone is not enough. Intraday buckets are fixed minute counts
  /// and every finer one tiles every coarser one exactly. Daily and above are
  /// *calendar* buckets: an intraday series only tiles a day if it covers the
  /// whole session, which no provider guarantees (pre/post-market, half days,
  /// gaps), so daily is refetched rather than folded up from minutes.
  bool canAggregateTo(BarInterval coarser) {
    if (coarser == this) return true;
    if (coarser.index <= index) return false;

    return switch (coarser) {
      // Reached only when `this` is strictly finer and therefore also
      // intraday, and fixed-minute buckets always tile.
      BarInterval.m5 ||
      BarInterval.m15 ||
      BarInterval.m30 ||
      BarInterval.h1 ||
      BarInterval.h4 =>
        true,
      BarInterval.d1 => false,
      BarInterval.w1 => this == BarInterval.d1,
      BarInterval.mo1 => this == BarInterval.d1 || this == BarInterval.w1,
      BarInterval.m1 => false,
    };
  }

  /// The start of the bucket [t] belongs to at this interval.
  ///
  /// Weeks start Monday; months start on the 1st. Intraday buckets are floored
  /// against the day, not against the epoch, so a 4H bucket does not straddle
  /// midnight differently in different timezones.
  DateTime bucketStart(DateTime t) {
    final DateTime day = DateTime.utc(t.year, t.month, t.day);
    switch (this) {
      case BarInterval.m1:
      case BarInterval.m5:
      case BarInterval.m15:
      case BarInterval.m30:
      case BarInterval.h1:
      case BarInterval.h4:
        final int minutes = t.difference(day).inMinutes;
        final int size = _intradayBucketMinutes;
        return day.add(Duration(minutes: minutes ~/ size * size));
      case BarInterval.d1:
        return day;
      case BarInterval.w1:
        // DateTime.weekday is 1 (Mon) .. 7 (Sun).
        return day.subtract(Duration(days: day.weekday - 1));
      case BarInterval.mo1:
        return DateTime.utc(t.year, t.month);
    }
  }

  /// Bucket size in minutes. Only meaningful for the intraday cases — daily
  /// and coarser are calendar buckets handled directly in [bucketStart], and
  /// a "month = 43200 minutes" constant would be quietly wrong.
  int get _intradayBucketMinutes => switch (this) {
        BarInterval.m1 => 1,
        BarInterval.m5 => 5,
        BarInterval.m15 => 15,
        BarInterval.m30 => 30,
        BarInterval.h1 => 60,
        BarInterval.h4 => 240,
        BarInterval.d1 ||
        BarInterval.w1 ||
        BarInterval.mo1 =>
          throw StateError('$label is a calendar bucket, not a minute count'),
      };

  static BarInterval fromLabel(String label) => BarInterval.values.firstWhere(
        (BarInterval i) => i.label == label,
        orElse: () => BarInterval.d1,
      );
}
