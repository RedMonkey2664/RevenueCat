import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/crypto_api_service.dart';
import '../../../core/services/fx_rate_service.dart';

/// A finished Time Machine calculation.
///
/// Every field is either user input or a fetched, sourced value. Nothing is
/// estimated, projected or interpolated — this is retrospective arithmetic on
/// two real prices (TIME_MACHINE.md).
@immutable
class TimeMachineResult {
  const TimeMachineResult({
    required this.amountInr,
    required this.label,
    required this.requestedDate,
    required this.priceThenInr,
    required this.priceNowInr,
    required this.btcThenUsd,
    required this.btcNowUsd,
    required this.fxThen,
    required this.fxNow,
  });

  final double amountInr;

  /// "What I bought instead" — cosmetic only, never used in the maths.
  final String label;

  final DateTime requestedDate;

  final double priceThenInr;
  final double priceNowInr;

  /// Kept for the disclosure, so the card can show its own working.
  final double btcThenUsd;
  final double btcNowUsd;
  final FxRate fxThen;
  final FxRate fxNow;

  /// price_now / price_on_date — the asset's actual move, not an assumed
  /// annual rate (TIME_MACHINE.md is explicit that this is not compound
  /// interest).
  double get multiple => priceNowInr / priceThenInr;

  double get valueNow => amountInr * multiple;

  /// Framed in the UI as "what it cost you". Can be negative — the honest
  /// answer when the asset fell, and the copy must handle that rather than
  /// only ever showing a triumphant number.
  double get gain => valueNow - amountInr;

  bool get isGain => gain >= 0;
}

/// Fetches the two prices Time Machine needs and does the arithmetic.
///
/// Results are cached for the session so dragging the date picker or editing
/// the amount does not re-hit the APIs (TIME_MACHINE.md: don't re-query on
/// every keystroke; respect free-tier limits).
class HistoricalPriceLookup {
  HistoricalPriceLookup({
    required CryptoApiService crypto,
    required FxRateService fx,
  })  : _crypto = crypto,
        _fx = fx;

  final CryptoApiService _crypto;
  final FxRateService _fx;

  final Map<String, double> _btcByDay = <String, double>{};
  final Map<String, FxRate> _fxByDay = <String, FxRate>{};

  double? _btcNow;
  FxRate? _fxNow;

  /// Earliest date the combined sources can answer for.
  DateTime get earliestDate => CryptoApiService.earliestDate;

  Future<TimeMachineResult> calculate({
    required double amountInr,
    required String label,
    required DateTime date,
  }) async {
    final String key = _dayKey(date);

    final double btcThen =
        _btcByDay[key] ??= await _crypto.btcCloseOnDate(date);
    final FxRate fxThen = _fxByDay[key] ??= await _fx.usdToInrOnDate(date);

    // "Now" is fetched once per session. A price that is minutes stale cannot
    // change a multi-year headline, and re-fetching it per keystroke would
    // burn the free tier for nothing.
    final double btcNow = _btcNow ??= await _crypto.btcPriceNow();
    final FxRate fxNow = _fxNow ??= await _fx.usdToInrNow();

    return TimeMachineResult(
      amountInr: amountInr,
      label: label,
      requestedDate: date,
      priceThenInr: btcThen * fxThen.usdToInr,
      priceNowInr: btcNow * fxNow.usdToInr,
      btcThenUsd: btcThen,
      btcNowUsd: btcNow,
      fxThen: fxThen,
      fxNow: fxNow,
    );
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final Provider<HistoricalPriceLookup> historicalPriceLookupProvider =
    Provider<HistoricalPriceLookup>(
  (Ref ref) => HistoricalPriceLookup(
    crypto: ref.watch(cryptoApiServiceProvider),
    fx: ref.watch(fxRateServiceProvider),
  ),
);
