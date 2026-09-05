import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../market_data_provider.dart';

/// Shared JSON fetch for the market-data providers.
///
/// Every network failure becomes a [MarketDataException] with copy a user can
/// act on. Providers never return a placeholder price on error — see the note
/// on [MarketDataException].
Future<Object?> fetchJson(
  http.Client client,
  Uri uri, {
  Map<String, String>? headers,
  Duration timeout = const Duration(seconds: 15),
  String sourceName = 'The market data service',
}) async {
  final http.Response response;
  try {
    response = await client.get(uri, headers: headers).timeout(timeout);
  } on Object catch (error) {
    debugPrint('Market data request failed: $uri — $error');
    throw MarketDataException(
      'Could not reach $sourceName. Check your connection and try again.',
    );
  }

  if (response.statusCode == 401 || response.statusCode == 403) {
    throw MarketDataException(
      '$sourceName rejected the request. Your session may have expired.',
      isAuthProblem: true,
    );
  }
  if (response.statusCode == 429) {
    throw MarketDataException(
      '$sourceName is rate-limiting us. Wait a moment and try again.',
    );
  }
  if (response.statusCode != 200) {
    throw MarketDataException(
      '$sourceName returned an error (${response.statusCode}).',
    );
  }

  try {
    return jsonDecode(response.body);
  } on FormatException {
    throw MarketDataException('$sourceName sent a malformed response.');
  }
}

/// Browser-ish UA. Yahoo's public chart endpoint 404s without one — the same
/// header `tool/import_yahoo_level.dart` already sends.
const String kBrowserUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Safari/537.36';
