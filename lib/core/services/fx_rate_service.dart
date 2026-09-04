import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'crypto_api_service.dart' show PriceLookupException;

/// A USD→INR rate together with the date it actually came from.
///
/// [dateUsed] can differ from the date asked for: the ECB publishes on
/// business days only, so a weekend query resolves to the previous working
/// day. Time Machine shows this in its disclosure rather than quietly
/// pretending the rate is from the requested date.
@immutable
class FxRate {
  const FxRate({required this.usdToInr, required this.dateUsed});

  final double usdToInr;
  final DateTime dateUsed;
}

/// USD→INR from the ECB's published reference rates, via Frankfurter.
///
/// NOT IN ARCHITECTURE.md — added because the app quotes everything in ₹
/// (DESIGN.md) while the only viable full-history Bitcoin source quotes USDT.
/// Multiplying a rupee amount by a dollar price ratio would silently ignore
/// the rupee's move over the period, which for a 2017 start is a large,
/// real distortion. That would be a fabricated number in the sense CLAUDE.md
/// cares about, so the conversion uses a real sourced rate at both ends.
///
/// Free, no key, no account.
class FxRateService {
  FxRateService({http.Client? client}) : _client = client ?? http.Client();

  static const String _host = 'api.frankfurter.dev';

  final http.Client _client;

  Future<FxRate> usdToInrOnDate(DateTime date) {
    final String day = _isoDay(date);
    return _fetch('/v1/$day');
  }

  Future<FxRate> usdToInrNow() => _fetch('/v1/latest');

  Future<FxRate> _fetch(String path) async {
    final Uri uri = Uri.https(_host, path, <String, String>{
      'base': 'USD',
      'symbols': 'INR',
    });

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 15));
    } on Object catch (error) {
      debugPrint('FX request failed: $error');
      throw const PriceLookupException(
        'Could not reach the exchange-rate service. Check your connection '
        'and try again.',
      );
    }

    if (response.statusCode != 200) {
      throw PriceLookupException(
        'The exchange-rate service returned an error '
        '(${response.statusCode}).',
      );
    }

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    final Map<String, dynamic> rates = json['rates'] as Map<String, dynamic>;
    final num? inr = rates['INR'] as num?;

    if (inr == null) {
      throw const PriceLookupException(
        'No rupee exchange rate was published for that date.',
      );
    }

    return FxRate(
      usdToInr: inr.toDouble(),
      dateUsed: DateTime.parse(json['date'] as String),
    );
  }

  static String _isoDay(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  void dispose() => _client.close();
}

final Provider<FxRateService> fxRateServiceProvider =
    Provider<FxRateService>((Ref ref) {
  final FxRateService service = FxRateService();
  ref.onDispose(service.dispose);
  return service;
});
