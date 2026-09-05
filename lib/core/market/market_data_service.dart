import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bar_interval.dart';
import 'broker_credentials.dart';
import 'candle.dart';
import 'instrument.dart';
import 'instrument_catalog.dart';
import 'market_data_provider.dart';
import 'providers/binance_market_provider.dart';
import 'providers/kotak_neo_provider.dart';
import 'providers/yahoo_market_provider.dart';

/// The app's single entry point for live market data.
///
/// Routes each request to a provider by market, caches results, and collapses
/// duplicate in-flight requests. Screens never touch a provider directly, so
/// swapping Yahoo for Kotak on Indian equity is a change to [_providerFor]
/// and nothing else.
///
/// ARCHITECTURE.md note — this adds a live data path to the Simulator, which
/// the original document forbade ("no backend for Simulator or Time Machine").
/// It is still not a *backend*: no server of ours, no deploy surface, same
/// posture as Time Machine's existing live price lookup. ARCHITECTURE.md has
/// been updated rather than left contradicting the app.
class MarketDataService {
  MarketDataService({
    required List<MarketDataProvider> providers,
    this.now = _systemNow,
  }) : _providers = providers;

  static DateTime _systemNow() => DateTime.now().toUtc();

  final List<MarketDataProvider> _providers;

  /// Injectable clock, so cache-expiry behaviour is testable.
  final DateTime Function() now;

  final Map<String, _CachedQuote> _quoteCache = <String, _CachedQuote>{};
  final Map<String, _CachedHistory> _historyCache = <String, _CachedHistory>{};
  final Map<String, Future<Object?>> _inFlight = <String, Future<Object?>>{};

  /// How long a quote stays fresh. Real-time feeds get a short window;
  /// delayed ones a longer one, because re-fetching a 15-minute-delayed price
  /// every 10 seconds burns rate limit for a number that has not moved.
  static const Duration _liveQuoteTtl = Duration(seconds: 15);
  static const Duration _delayedQuoteTtl = Duration(seconds: 60);

  /// Historical bars change only when a new bar closes. A minute is plenty
  /// and keeps a chart's timeframe toggling instant.
  static const Duration _historyTtl = Duration(minutes: 1);

  List<MarketDataProvider> get providers =>
      List<MarketDataProvider>.unmodifiable(_providers);

  /// The provider that will serve [instrument].
  ///
  /// A ready broker provider wins over a public one for the same market —
  /// that is the whole point of connecting an account. An unready one is
  /// skipped silently, which is what makes Kotak an upgrade rather than a
  /// dependency.
  MarketDataProvider _providerFor(Instrument instrument) {
    MarketDataProvider? fallback;
    for (final MarketDataProvider p in _providers) {
      if (!p.regions.contains(instrument.region)) continue;
      if (p.isReady) return p;
      fallback ??= p;
    }
    if (fallback != null && fallback.isReady) return fallback;

    for (final MarketDataProvider p in _providers) {
      if (p.regions.contains(instrument.region) && p.isReady) return p;
    }

    throw MarketDataException(
      'No data source is available for ${instrument.region.label} markets.',
    );
  }

  /// The source that will actually answer for [instrument], for attribution.
  String sourceLabelFor(Instrument instrument) {
    try {
      final MarketDataProvider p = _providerFor(instrument);
      return p.isDelayed ? '${p.displayName} · delayed' : p.displayName;
    } on MarketDataException {
      return 'unavailable';
    }
  }

  List<BarInterval> intervalsFor(Instrument instrument) {
    try {
      return _providerFor(instrument).intervalsFor(instrument);
    } on MarketDataException {
      return const <BarInterval>[BarInterval.d1];
    }
  }

  Duration maxHistoryFor(Instrument instrument, BarInterval interval) {
    try {
      return _providerFor(instrument).maxHistoryFor(interval);
    } on MarketDataException {
      return const Duration(days: 365);
    }
  }

  Future<Quote> quote(Instrument instrument, {bool force = false}) async {
    final MarketDataProvider provider = _providerFor(instrument);
    final String key = 'q:${provider.id}:${instrument.id}';
    final Duration ttl =
        provider.isDelayed ? _delayedQuoteTtl : _liveQuoteTtl;

    if (!force) {
      final _CachedQuote? hit = _quoteCache[key];
      if (hit != null && now().difference(hit.at) < ttl) return hit.quote;
    }

    return _dedupe(key, () async {
      final Quote q = await provider.quote(instrument);
      _quoteCache[key] = _CachedQuote(q, now());
      return q;
    });
  }

  /// Quotes for a watchlist.
  ///
  /// Grouped by provider so a batch-capable one is asked once, and failures
  /// are per-instrument: one dead symbol must not blank the whole list.
  Future<Map<String, Quote>> quotesFor(
    List<Instrument> instruments, {
    bool force = false,
  }) async {
    final Map<String, Quote> out = <String, Quote>{};

    await Future.wait(
      instruments.map((Instrument i) async {
        try {
          out[i.id] = await quote(i, force: force);
        } on MarketDataException catch (e) {
          debugPrint('Quote failed for ${i.id}: $e');
        }
      }),
    );

    return out;
  }

  /// Historical bars for a chart.
  Future<List<Candle>> history(
    Instrument instrument, {
    required BarInterval interval,
    DateTime? from,
    DateTime? to,
    bool force = false,
  }) async {
    final MarketDataProvider provider = _providerFor(instrument);

    // The interval may not be native to the provider (Yahoo has no 4H). Fetch
    // the finest interval that can be folded into it, and let the chart do
    // the folding — one aggregation implementation, not two.
    final BarInterval fetch =
        _nativeIntervalFor(provider, instrument, interval);

    final String key = 'h:${provider.id}:${instrument.id}:${fetch.label}'
        ':${from?.toIso8601String() ?? ''}:${to?.toIso8601String() ?? ''}';

    if (!force) {
      final _CachedHistory? hit = _historyCache[key];
      if (hit != null && now().difference(hit.at) < _historyTtl) {
        return hit.candles;
      }
    }

    return _dedupe(key, () async {
      final List<Candle> bars = await provider.history(
        instrument,
        interval: fetch,
        from: from,
        to: to,
      );
      _historyCache[key] = _CachedHistory(bars, now());
      return bars;
    });
  }

  /// The interval actually requested from [provider] to satisfy [wanted].
  ///
  /// Exposed so a chart host knows what base interval it is holding, and can
  /// therefore work out which timeframes it can offer without a refetch.
  BarInterval nativeIntervalFor(
    Instrument instrument,
    BarInterval wanted,
  ) {
    try {
      return _nativeIntervalFor(_providerFor(instrument), instrument, wanted);
    } on MarketDataException {
      return wanted;
    }
  }

  static BarInterval _nativeIntervalFor(
    MarketDataProvider provider,
    Instrument instrument,
    BarInterval wanted,
  ) {
    final List<BarInterval> supported = provider.intervalsFor(instrument);
    if (supported.contains(wanted)) return wanted;

    // Coarsest supported interval that still folds into what was asked for.
    for (int i = wanted.index - 1; i >= 0; i--) {
      final BarInterval candidate = BarInterval.values[i];
      if (supported.contains(candidate) &&
          candidate.canAggregateTo(wanted)) {
        return candidate;
      }
    }

    throw MarketDataException(
      '${provider.displayName} cannot provide ${wanted.longLabel} bars for '
      '${instrument.ticker}.',
    );
  }

  /// Symbol search: the bundled catalog first (instant, offline), then the
  /// provider's own endpoint for anything else.
  Future<List<Instrument>> search(String query, {MarketRegion? region}) async {
    final List<Instrument> local =
        InstrumentCatalog.search(query, region: region);
    if (query.trim().length < 2) return local;

    final List<Instrument> remote = <Instrument>[];
    for (final MarketDataProvider p in _providers) {
      if (!p.isReady) continue;
      if (region != null && !p.regions.contains(region)) continue;
      try {
        remote.addAll(await p.search(query));
      } on MarketDataException catch (e) {
        debugPrint('Search failed on ${p.id}: $e');
      }
    }

    final Set<String> seen = <String>{for (final Instrument i in local) i.id};
    return <Instrument>[
      ...local,
      ...remote.where((Instrument i) =>
          seen.add(i.id) && (region == null || i.region == region)),
    ];
  }

  /// Collapses concurrent identical requests — a watchlist and an open chart
  /// asking for the same symbol at once should make one network call.
  Future<T> _dedupe<T>(String key, Future<T> Function() run) async {
    final Future<Object?>? existing = _inFlight[key];
    if (existing != null) return await existing as T;

    final Future<T> future = run();
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  void clearCache() {
    _quoteCache.clear();
    _historyCache.clear();
  }

  void dispose() {
    for (final MarketDataProvider p in _providers) {
      p.dispose();
    }
  }
}

class _CachedQuote {
  const _CachedQuote(this.quote, this.at);

  final Quote quote;
  final DateTime at;
}

class _CachedHistory {
  const _CachedHistory(this.candles, this.at);

  final List<Candle> candles;
  final DateTime at;
}

/// The app's market-data service.
///
/// Rebuilds when the broker connection changes, so connecting or signing out
/// of Kotak Neo re-routes Indian equity without a restart.
final Provider<MarketDataService> marketDataServiceProvider =
    Provider<MarketDataService>((Ref ref) {
  final BrokerCredentialStore store =
      ref.watch(brokerCredentialStoreProvider);
  ref.watch(brokerConnectionRevisionProvider);

  final MarketDataService service = MarketDataService(
    providers: <MarketDataProvider>[
      // Order matters only within a region: the first *ready* provider for a
      // market wins, so the broker is listed ahead of the public fallback.
      KotakNeoProvider(
        credentials: store.readCredentials(),
        session: store.readSession(),
      ),
      YahooMarketProvider(),
      BinanceMarketProvider(),
    ],
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Bumped whenever the broker connection changes, to invalidate the service.
///
/// A plain revision counter rather than the connection state itself: the
/// service only needs to know that *something* changed, and the credential
/// store is the single source of truth for what.
final NotifierProvider<BrokerConnectionRevision, int>
    brokerConnectionRevisionProvider =
    NotifierProvider<BrokerConnectionRevision, int>(
  BrokerConnectionRevision.new,
);

class BrokerConnectionRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}
