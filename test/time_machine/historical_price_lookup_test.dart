import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:market_nerve/core/services/crypto_api_service.dart';
import 'package:market_nerve/core/services/fx_rate_service.dart';
import 'package:market_nerve/features/time_machine/services/historical_price_lookup.dart';

/// Counts requests so the session-cache behaviour can be asserted rather than
/// assumed — TIME_MACHINE.md requires not re-querying on every keystroke.
class _Counter {
  int klines = 0;
  int ticker = 0;
  int fxHistoric = 0;
  int fxLatest = 0;
}

({HistoricalPriceLookup lookup, _Counter counts}) buildLookup({
  double btcThen = 13539.93,
  double btcNow = 76000,
  double fxThen = 63.517,
  double fxNow = 94.97,
  int klineStatus = 200,
  int fxStatus = 200,
  bool emptyKlines = false,
}) {
  final _Counter counts = _Counter();

  final MockClient binance = MockClient((http.Request request) async {
    if (request.url.path.contains('klines')) {
      counts.klines++;
      if (klineStatus != 200) {
        return http.Response('nope', klineStatus);
      }
      if (emptyKlines) return http.Response('[]', 200);
      return http.Response(
        jsonEncode(<List<dynamic>>[
          <dynamic>[
            1515974400000,
            '13477.98',
            '14249.99',
            '13147.79',
            btcThen.toString(),
            '14652.09',
          ],
        ]),
        200,
      );
    }
    counts.ticker++;
    return http.Response(
      jsonEncode(<String, String>{
        'symbol': 'BTCUSDT',
        'price': btcNow.toString(),
      }),
      200,
    );
  });

  final MockClient frankfurter = MockClient((http.Request request) async {
    if (fxStatus != 200) return http.Response('nope', fxStatus);
    final bool latest = request.url.path.endsWith('latest');
    if (latest) {
      counts.fxLatest++;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'date': '2026-09-02',
          'rates': <String, dynamic>{'INR': fxNow},
        }),
        200,
      );
    }
    counts.fxHistoric++;
    return http.Response(
      jsonEncode(<String, dynamic>{
        // Deliberately not the requested date: the ECB skips weekends.
        'date': '2018-01-12',
        'rates': <String, dynamic>{'INR': fxThen},
      }),
      200,
    );
  });

  return (
    lookup: HistoricalPriceLookup(
      crypto: CryptoApiService(client: binance),
      fx: FxRateService(client: frankfurter),
    ),
    counts: counts,
  );
}

void main() {
  group('TimeMachineResult maths', () {
    test('multiplies by the ratio of the two rupee prices', () async {
      final ({HistoricalPriceLookup lookup, _Counter counts}) h = buildLookup();

      final TimeMachineResult r = await h.lookup.calculate(
        amountInr: 80000,
        label: 'a Royal Enfield',
        date: DateTime(2018, 1, 15),
      );

      final double expectedThen = 13539.93 * 63.517;
      final double expectedNow = 76000 * 94.97;

      expect(r.priceThenInr, closeTo(expectedThen, 0.01));
      expect(r.priceNowInr, closeTo(expectedNow, 0.01));
      expect(r.multiple, closeTo(expectedNow / expectedThen, 0.0001));
      expect(r.valueNow, closeTo(80000 * r.multiple, 0.01));
      expect(r.gain, closeTo(r.valueNow - 80000, 0.01));
      expect(r.isGain, isTrue);
    });

    test('the rupee conversion is applied at both ends, not ignored', () async {
      // Same BTC move, different FX. If the rupee leg were dropped, these two
      // results would be identical — and the headline would understate an
      // Indian investor's actual return.
      final ({HistoricalPriceLookup lookup, _Counter counts}) flatFx =
          buildLookup(fxThen: 60, fxNow: 60);
      final ({HistoricalPriceLookup lookup, _Counter counts}) weakerRupee =
          buildLookup(fxThen: 60, fxNow: 90);

      final TimeMachineResult a = await flatFx.lookup.calculate(
        amountInr: 80000,
        label: 'x',
        date: DateTime(2018, 1, 15),
      );
      final TimeMachineResult b = await weakerRupee.lookup.calculate(
        amountInr: 80000,
        label: 'x',
        date: DateTime(2018, 1, 15),
      );

      expect(b.multiple, greaterThan(a.multiple));
      expect(b.multiple / a.multiple, closeTo(1.5, 0.0001));
    });

    test('a fall is reported honestly as a loss', () async {
      final ({HistoricalPriceLookup lookup, _Counter counts}) h =
          buildLookup(btcThen: 60000, btcNow: 30000, fxThen: 80, fxNow: 80);

      final TimeMachineResult r = await h.lookup.calculate(
        amountInr: 80000,
        label: 'x',
        date: DateTime(2022, 1, 15),
      );

      expect(r.isGain, isFalse);
      expect(r.gain, lessThan(0));
      expect(r.valueNow, closeTo(40000, 0.01));
    });

    test('keeps the FX date actually used, not the one requested', () async {
      final ({HistoricalPriceLookup lookup, _Counter counts}) h = buildLookup();
      final TimeMachineResult r = await h.lookup.calculate(
        amountInr: 1000,
        label: 'x',
        date: DateTime(2018, 1, 14),
      );

      expect(r.requestedDate, DateTime(2018, 1, 14));
      expect(r.fxThen.dateUsed, DateTime(2018, 1, 12));
    });
  });

  group('Session caching', () {
    test('does not re-query when only the amount changes', () async {
      final ({HistoricalPriceLookup lookup, _Counter counts}) h = buildLookup();
      final DateTime date = DateTime(2018, 1, 15);

      await h.lookup.calculate(amountInr: 1000, label: 'x', date: date);
      await h.lookup.calculate(amountInr: 9999, label: 'y', date: date);
      await h.lookup.calculate(amountInr: 5, label: 'z', date: date);

      expect(h.counts.klines, 1);
      expect(h.counts.fxHistoric, 1);
      expect(h.counts.ticker, 1);
      expect(h.counts.fxLatest, 1);
    });

    test('fetches historic data again for a different date', () async {
      final ({HistoricalPriceLookup lookup, _Counter counts}) h = buildLookup();

      await h.lookup.calculate(
        amountInr: 1000,
        label: 'x',
        date: DateTime(2018, 1, 15),
      );
      await h.lookup.calculate(
        amountInr: 1000,
        label: 'x',
        date: DateTime(2019, 6, 1),
      );

      expect(h.counts.klines, 2);
      expect(h.counts.fxHistoric, 2);
      // "Now" is still only fetched once per session.
      expect(h.counts.ticker, 1);
      expect(h.counts.fxLatest, 1);
    });
  });

  group('Failure never becomes a number', () {
    test('a date before the source coverage is refused', () async {
      final ({HistoricalPriceLookup lookup, _Counter counts}) h = buildLookup();

      expect(
        () => h.lookup.calculate(
          amountInr: 1000,
          label: 'x',
          date: DateTime(2015, 1, 1),
        ),
        throwsA(isA<PriceLookupException>()),
      );
      expect(h.counts.klines, 0, reason: 'should not even hit the network');
    });

    test('a price-service error surfaces rather than falling back', () async {
      final ({HistoricalPriceLookup lookup, _Counter counts}) h =
          buildLookup(klineStatus: 500);

      expect(
        () => h.lookup.calculate(
          amountInr: 1000,
          label: 'x',
          date: DateTime(2018, 1, 15),
        ),
        throwsA(isA<PriceLookupException>()),
      );
    });

    test('an FX error surfaces rather than assuming a rate', () async {
      final ({HistoricalPriceLookup lookup, _Counter counts}) h =
          buildLookup(fxStatus: 503);

      expect(
        () => h.lookup.calculate(
          amountInr: 1000,
          label: 'x',
          date: DateTime(2018, 1, 15),
        ),
        throwsA(isA<PriceLookupException>()),
      );
    });

    test('a day with no published candle is an error, not a guess', () async {
      final ({HistoricalPriceLookup lookup, _Counter counts}) h =
          buildLookup(emptyKlines: true);

      expect(
        () => h.lookup.calculate(
          amountInr: 1000,
          label: 'x',
          date: DateTime(2018, 1, 15),
        ),
        throwsA(isA<PriceLookupException>()),
      );
    });
  });

  test('coverage floor matches the verified start of BTCUSDT', () {
    expect(CryptoApiService.earliestDate, DateTime.utc(2017, 8, 17));
  });
}
