import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Raised when a price genuinely cannot be fetched.
///
/// Never swallowed into a fallback number: CLAUDE.md forbids presenting an
/// invented figure as a historical fact, and a silently wrong "what it cost
/// you" headline is exactly that.
class PriceLookupException implements Exception {
  const PriceLookupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Bitcoin prices from Binance's public market-data endpoint.
///
/// WHY BINANCE AND NOT COINGECKO — this reverses TIME_MACHINE.md's default:
/// CoinGecko's free and demo tiers cap historical queries at the **past 365
/// days** (error 10012). Time Machine's entire premise is "what if you had
/// bought this in 2018", so that tier cannot serve the feature at all.
/// Binance's public data API returns full daily history with no key and no
/// date cap. TIME_MACHINE.md already names Binance as an acceptable source.
///
/// The trade-off: Binance quotes BTC in USDT, not INR, so [FxRateService]
/// converts. That is why the share card's disclosure names two sources.
class CryptoApiService {
  CryptoApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Public market-data host. Read-only, no key, no account.
  static const String _host = 'data-api.binance.vision';
  static const String _symbol = 'BTCUSDT';

  /// Binance's BTCUSDT pair opens here. Verified against the API: the first
  /// daily candle is 2017-08-17 UTC. This is the hard floor on Time Machine's
  /// date picker (TIME_MACHINE.md: never let a user pick a date the source
  /// does not cover).
  static final DateTime earliestDate = DateTime.utc(2017, 8, 17);

  final http.Client _client;

  /// Daily close for [date], in USDT.
  ///
  /// Uses the close of that calendar day's candle. Crypto trades 24/7, so
  /// unlike equities there is no missing-weekend problem here.
  Future<double> btcCloseOnDate(DateTime date) async {
    final DateTime day = DateTime.utc(date.year, date.month, date.day);

    if (day.isBefore(earliestDate)) {
      throw PriceLookupException(
        'Bitcoin price data starts on '
        '${earliestDate.toIso8601String().split('T').first}.',
      );
    }

    final Uri uri = Uri.https(_host, '/api/v3/klines', <String, String>{
      'symbol': _symbol,
      'interval': '1d',
      'startTime': day.millisecondsSinceEpoch.toString(),
      'limit': '1',
    });

    final List<dynamic> rows = await _getJson(uri) as List<dynamic>;
    if (rows.isEmpty) {
      throw const PriceLookupException(
        'No Bitcoin price was published for that day.',
      );
    }

    // Kline layout: [openTime, open, high, low, close, ...].
    final List<dynamic> row = rows.first as List<dynamic>;
    return double.parse(row[4] as String);
  }

  /// The latest traded price, in USDT.
  Future<double> btcPriceNow() async {
    final Uri uri = Uri.https(_host, '/api/v3/ticker/price', <String, String>{
      'symbol': _symbol,
    });
    final Map<String, dynamic> json =
        await _getJson(uri) as Map<String, dynamic>;
    return double.parse(json['price'] as String);
  }

  Future<Object?> _getJson(Uri uri) async {
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 15));
    } on Object catch (error) {
      debugPrint('Price request failed: $error');
      throw const PriceLookupException(
        'Could not reach the price service. Check your connection and try '
        'again.',
      );
    }

    if (response.statusCode != 200) {
      throw PriceLookupException(
        'The price service returned an error (${response.statusCode}).',
      );
    }

    return jsonDecode(response.body);
  }

  void dispose() => _client.close();
}

final Provider<CryptoApiService> cryptoApiServiceProvider =
    Provider<CryptoApiService>((Ref ref) {
  final CryptoApiService service = CryptoApiService();
  ref.onDispose(service.dispose);
  return service;
});
