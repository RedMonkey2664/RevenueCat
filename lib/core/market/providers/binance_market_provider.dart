import 'package:http/http.dart' as http;

import '../bar_interval.dart';
import '../candle.dart';
import '../instrument.dart';
import '../market_data_provider.dart';
import 'http_json.dart';

/// Crypto quotes and history from Binance's public market-data host.
///
/// No key, no account, no date cap — the same source `CryptoApiService`
/// already uses for Time Machine, and for the same reason: CoinGecko's free
/// tier caps history at 365 days, which cannot serve either feature.
///
/// Prices are real-time, so [isDelayed] is false. This is the provider that
/// makes the Live Markets tab demo well at any hour: crypto trades 24/7, so
/// there is never a "market closed" screen.
class BinanceMarketProvider extends MarketDataProvider {
  BinanceMarketProvider({http.Client? client})
      : _client = client ?? http.Client();

  static const String _host = 'data-api.binance.vision';

  /// Binance caps a klines page at 1000 bars.
  static const int _maxLimit = 1000;

  final http.Client _client;

  @override
  String get id => 'binance';

  @override
  String get displayName => 'Binance';

  @override
  Set<MarketRegion> get regions => <MarketRegion>{MarketRegion.crypto};

  @override
  bool get isReady => true;

  @override
  String? get notReadyReason => null;

  @override
  bool get isDelayed => false;

  @override
  List<BarInterval> intervalsFor(Instrument instrument) =>
      BarInterval.values;

  @override
  Duration maxHistoryFor(BarInterval interval) =>
      const Duration(days: 365 * 20);

  static String _wire(BarInterval i) => switch (i) {
        BarInterval.m1 => '1m',
        BarInterval.m5 => '5m',
        BarInterval.m15 => '15m',
        BarInterval.m30 => '30m',
        BarInterval.h1 => '1h',
        BarInterval.h4 => '4h',
        BarInterval.d1 => '1d',
        BarInterval.w1 => '1w',
        BarInterval.mo1 => '1M',
      };

  @override
  Future<Quote> quote(Instrument instrument) async {
    final Uri uri = Uri.https(_host, '/api/v3/ticker/24hr', <String, String>{
      'symbol': instrument.symbol,
    });

    final Object? json =
        await fetchJson(_client, uri, sourceName: 'Binance');
    final Map<String, dynamic> t = json as Map<String, dynamic>;

    final double price = double.parse(t['lastPrice'] as String);
    final double prev = double.parse(t['prevClosePrice'] as String);

    return Quote(
      instrument: instrument,
      price: price,
      // Binance reports 0.00 for a pair with no prior session rather than
      // omitting it; treating that as the previous close would render a
      // +infinity% move.
      previousClose: prev > 0 ? prev : price,
      asOf: DateTime.fromMillisecondsSinceEpoch(
        (t['closeTime'] as num).toInt(),
        isUtc: true,
      ),
      source: 'Binance · live',
      dayHigh: double.tryParse(t['highPrice'] as String? ?? ''),
      dayLow: double.tryParse(t['lowPrice'] as String? ?? ''),
      dayOpen: double.tryParse(t['openPrice'] as String? ?? ''),
      volume: double.tryParse(t['volume'] as String? ?? ''),
    );
  }

  @override
  Future<List<Candle>> history(
    Instrument instrument, {
    required BarInterval interval,
    DateTime? from,
    DateTime? to,
  }) async {
    final DateTime end = to ?? DateTime.now().toUtc();
    final DateTime start =
        from ?? end.subtract(const Duration(days: 365));

    final List<Candle> out = <Candle>[];
    int cursor = start.millisecondsSinceEpoch;
    final int endMs = end.millisecondsSinceEpoch;

    // Page forward until the window is covered. Bounded so a pathological
    // request (1m bars over ten years) cannot loop indefinitely.
    for (int page = 0; page < 40 && cursor < endMs; page++) {
      final Uri uri = Uri.https(_host, '/api/v3/klines', <String, String>{
        'symbol': instrument.symbol,
        'interval': _wire(interval),
        'startTime': cursor.toString(),
        'endTime': endMs.toString(),
        'limit': '$_maxLimit',
      });

      final Object? json =
          await fetchJson(_client, uri, sourceName: 'Binance');
      final List<dynamic> rows = json as List<dynamic>;
      if (rows.isEmpty) break;

      for (final dynamic raw in rows) {
        // Kline layout: [openTime, open, high, low, close, volume, ...].
        final List<dynamic> r = raw as List<dynamic>;
        out.add(
          Candle(
            date: DateTime.fromMillisecondsSinceEpoch(
              (r[0] as num).toInt(),
              isUtc: true,
            ),
            open: double.parse(r[1] as String),
            high: double.parse(r[2] as String),
            low: double.parse(r[3] as String),
            close: double.parse(r[4] as String),
            volume: double.parse(r[5] as String),
          ),
        );
      }

      if (rows.length < _maxLimit) break;
      cursor = out.last.date.millisecondsSinceEpoch + 1;
    }

    return out;
  }

  @override
  void dispose() => _client.close();
}
