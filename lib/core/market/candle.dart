import 'package:meta/meta.dart';

/// One OHLC bar.
///
/// Lives in `core/` because it is now the shared vocabulary between the
/// market-data layer, the chart and the Simulator engine — three things that
/// must agree on what a bar is. `features/simulator/engine/candle_model.dart`
/// re-exports it, so the engine's existing imports and tests are unchanged.
///
/// [date] is UTC by convention. For daily and coarser bars it is a calendar
/// day at midnight; for intraday bars it is the bar's opening timestamp.
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

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': dateKey,
        'open': open,
        'high': high,
        'low': low,
        'close': close,
        if (volume != null) 'volume': volume,
      };

  @override
  String toString() => 'Candle($dateKey, o:$open h:$high l:$low c:$close)';
}
