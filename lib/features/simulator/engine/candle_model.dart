import 'package:meta/meta.dart';

/// One OHLC bar. The Simulator is 1D-only (DESIGN.md: one real timeframe),
/// so [date] is always a calendar day.
@immutable
class Candle {
  const Candle({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume,
  });

  factory Candle.fromJson(Map<String, dynamic> json) {
    return Candle(
      date: DateTime.parse(json['date'] as String),
      open: (json['open'] as num).toDouble(),
      high: (json['high'] as num).toDouble(),
      low: (json['low'] as num).toDouble(),
      close: (json['close'] as num).toDouble(),
      volume: (json['volume'] as num?)?.toDouble(),
    );
  }

  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final double? volume;

  bool get isUp => close >= open;

  /// Calendar day key, used to resolve a script's `trigger_date` to an index.
  String get dateKey =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  String toString() => 'Candle($dateKey, o:$open h:$high l:$low c:$close)';
}
