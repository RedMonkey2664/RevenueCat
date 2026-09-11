import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/market/bar_interval.dart';
import '../../../core/market/candle.dart';
import '../../../core/market/instrument.dart';
import '../../../core/market/instrument_catalog.dart';
import '../../../core/market/market_data_service.dart';
import '../model/pivot_models.dart';

class PivotPriceException implements Exception {
  const PivotPriceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Every price the Daily Pivot uses, from Binance's public BTC/USDT feed,
/// through the app's one market-data service (ARCHITECTURE.md: screens ask
/// the service, never a provider).
///
/// The strike and the resolution are read from real one-minute bars at the
/// two fixed instants, so either can be checked by anyone against the
/// exchange's own data — nothing here is estimated.
class PivotPriceService {
  const PivotPriceService(this._market);

  final MarketDataService _market;

  static final Instrument btc = InstrumentCatalog.byId('binance:BTCUSDT')!;

  /// e.g. "Binance · live" — shown under every Pivot price.
  String get sourceLabel => _market.sourceLabelFor(btc);

  /// BTC/USDT at 09:00 IST: the open of that minute's bar.
  Future<double> strikeFor(String dayKey) async {
    final DateTime open = PivotClock.openUtc(dayKey);
    final List<Candle> bars = await _market.history(
      btc,
      interval: BarInterval.m1,
      from: open,
      to: open.add(const Duration(minutes: 1)),
    );
    if (bars.isEmpty) {
      throw const PivotPriceException(
        'Binance returned no price for 09:00 IST today.',
      );
    }
    final Candle bar = bars.firstWhere(
      (Candle c) => c.date.isAtSameMomentAs(open),
      orElse: () => bars.first,
    );
    return bar.open;
  }

  /// BTC/USDT at 17:00 IST: the close of the 16:59 bar. Null until that bar
  /// exists — the day cannot be resolved from a bar that has not closed.
  Future<double?> closeFor(String dayKey) async {
    final DateTime close = PivotClock.closeUtc(dayKey);
    final DateTime lastMinute = close.subtract(const Duration(minutes: 1));
    final List<Candle> bars = await _market.history(
      btc,
      interval: BarInterval.m1,
      from: lastMinute,
      to: close,
      force: true,
    );
    for (final Candle c in bars) {
      if (c.date.isAtSameMomentAs(lastMinute)) return c.close;
    }
    return null;
  }

  Future<Quote> live() => _market.quote(btc, force: true);

  /// The last ten hours in 15-minute bars — the tape the Pivot draws.
  Future<List<Candle>> tape(DateTime nowUtc) => _market.history(
    btc,
    interval: BarInterval.m15,
    from: nowUtc.subtract(const Duration(hours: 10)),
    to: nowUtc,
  );
}

final Provider<PivotPriceService> pivotPriceServiceProvider =
    Provider<PivotPriceService>(
      (Ref ref) => PivotPriceService(ref.watch(marketDataServiceProvider)),
    );
