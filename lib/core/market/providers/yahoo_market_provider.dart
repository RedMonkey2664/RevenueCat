import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../bar_interval.dart';
import '../candle.dart';
import '../instrument.dart';
import '../market_data_provider.dart';
import 'http_json.dart';

/// Equity quotes and history from Yahoo Finance's public chart endpoint.
///
/// ⚠ LICENSING — the same caveat `tool/import_yahoo_level.dart` carries, but
/// a *different* one in kind, and the difference matters:
///
///   • The importer BUNDLES Yahoo data into the shipped app. Yahoo's terms do
///     not permit that, which is why every campaign level is marked
///     "licence": "unverified".
///   • This provider QUERIES Yahoo live and caches only for the session. That
///     is the same posture CLAUDE.md already accepts for CoinGecko/Binance in
///     Time Machine ("not bundled/redistributed — queried live").
///
/// That distinction makes this materially lower-risk than the bundled levels,
/// but it is not a clearance: Yahoo's terms restrict commercial redistribution
/// of their feed regardless of caching, and index values remain the index
/// provider's IP. Treat this as the working default until the Kotak Neo
/// credentials arrive, and swap `regions` to drop equity here once they do.
/// Somi has been told; see the note in the build summary.
///
/// Prices are delayed (typically 15 minutes for Indian and US equity), which
/// [isDelayed] reports so the UI can label them honestly.
class YahooMarketProvider extends MarketDataProvider {
  YahooMarketProvider({http.Client? client})
      : _client = client ?? http.Client();

  static const String _host = 'query1.finance.yahoo.com';

  /// Same-origin proxy used by the web build only (`api/yahoo.js`).
  ///
  /// Yahoo sends no `Access-Control-Allow-Origin`, so a browser discards the
  /// response and every equity row reads "unavailable". Native builds have no
  /// CORS and call Yahoo directly — going through the proxy there would add a
  /// hop, a dependency and a shared rate-limit bucket for nothing.
  static const String _webProxyPath = '/api/yahoo';

  final http.Client _client;

  /// Builds a request URL, routed through the proxy on web.
  ///
  /// Resolved against [Uri.base] rather than left relative: `package:http`
  /// requires an absolute URL, and `Uri.base` is the page origin on web, so
  /// this follows the deployment without the URL being configured anywhere.
  static Uri _endpoint(String path, Map<String, String> params) {
    if (!kIsWeb) return Uri.https(_host, path, params);
    return Uri.base.resolve(_webProxyPath).replace(
          queryParameters: <String, String>{'path': path, ...params},
        );
  }

  @override
  String get id => 'yahoo';

  @override
  String get displayName => 'Yahoo Finance';

  @override
  Set<MarketRegion> get regions =>
      <MarketRegion>{MarketRegion.usEquity, MarketRegion.indiaEquity};

  @override
  bool get isReady => true;

  @override
  String? get notReadyReason => null;

  @override
  bool get isDelayed => true;

  @override
  List<BarInterval> intervalsFor(Instrument instrument) => const <BarInterval>[
        BarInterval.m1,
        BarInterval.m5,
        BarInterval.m15,
        BarInterval.m30,
        BarInterval.h1,
        BarInterval.d1,
        BarInterval.w1,
        BarInterval.mo1,
      ];

  /// Yahoo's documented intraday retention. Requesting more silently returns
  /// a truncated series, so the caller clamps against this instead of
  /// showing a range that quietly did not arrive.
  @override
  Duration maxHistoryFor(BarInterval interval) => switch (interval) {
        BarInterval.m1 => const Duration(days: 7),
        BarInterval.m5 ||
        BarInterval.m15 ||
        BarInterval.m30 =>
          const Duration(days: 60),
        BarInterval.h1 || BarInterval.h4 => const Duration(days: 730),
        BarInterval.d1 ||
        BarInterval.w1 ||
        BarInterval.mo1 =>
          const Duration(days: 365 * 60),
      };

  /// Yahoo has no 4H bar; the service folds 1H into 4H instead.
  static String? _wireInterval(BarInterval i) => switch (i) {
        BarInterval.m1 => '1m',
        BarInterval.m5 => '5m',
        BarInterval.m15 => '15m',
        BarInterval.m30 => '30m',
        BarInterval.h1 => '60m',
        BarInterval.h4 => null,
        BarInterval.d1 => '1d',
        BarInterval.w1 => '1wk',
        BarInterval.mo1 => '1mo',
      };

  @override
  Future<Quote> quote(Instrument instrument) async {
    final Map<String, dynamic> result = await _chart(
      instrument,
      params: <String, String>{'interval': '1d', 'range': '5d'},
    );
    final Map<String, dynamic> meta =
        result['meta'] as Map<String, dynamic>;

    final double? price = (meta['regularMarketPrice'] as num?)?.toDouble();
    if (price == null) {
      throw MarketDataException(
        'Yahoo Finance did not return a price for ${instrument.ticker}.',
      );
    }

    final int? epoch = (meta['regularMarketTime'] as num?)?.toInt();

    return Quote(
      instrument: instrument,
      price: price,
      previousClose:
          (meta['chartPreviousClose'] as num?)?.toDouble() ??
              (meta['previousClose'] as num?)?.toDouble() ??
              price,
      asOf: epoch == null
          ? DateTime.now().toUtc()
          : DateTime.fromMillisecondsSinceEpoch(epoch * 1000, isUtc: true),
      source: 'Yahoo Finance · delayed',
      dayHigh: (meta['regularMarketDayHigh'] as num?)?.toDouble(),
      dayLow: (meta['regularMarketDayLow'] as num?)?.toDouble(),
      volume: (meta['regularMarketVolume'] as num?)?.toDouble(),
    );
  }

  @override
  Future<List<Candle>> history(
    Instrument instrument, {
    required BarInterval interval,
    DateTime? from,
    DateTime? to,
  }) async {
    final String? wire = _wireInterval(interval);
    if (wire == null) {
      throw MarketDataException(
        'Yahoo Finance does not publish ${interval.longLabel} bars.',
      );
    }

    final DateTime end = to ?? DateTime.now().toUtc();
    final DateTime earliest = end.subtract(maxHistoryFor(interval));
    DateTime start = from ?? end.subtract(const Duration(days: 365));
    if (start.isBefore(earliest)) start = earliest;

    final Map<String, dynamic> result = await _chart(
      instrument,
      params: <String, String>{
        'interval': wire,
        'period1': (start.millisecondsSinceEpoch ~/ 1000).toString(),
        // Yahoo's period2 is exclusive-ish at the bar level; a day of slack
        // guarantees the final session is included.
        'period2':
            ((end.millisecondsSinceEpoch ~/ 1000) + 86400).toString(),
      },
    );

    return _candlesFrom(result);
  }

  @override
  Future<List<Instrument>> search(String query) async {
    if (query.trim().isEmpty) return const <Instrument>[];

    final Uri uri = _endpoint('/v1/finance/search', <String, String>{
      'q': query,
      'quotesCount': '12',
      'newsCount': '0',
    });

    final Object? json = await fetchJson(
      _client,
      uri,
      headers: <String, String>{'User-Agent': kBrowserUserAgent},
      sourceName: 'Yahoo Finance',
    );

    final List<dynamic> quotes =
        ((json as Map<String, dynamic>)['quotes'] as List<dynamic>?) ??
            const <dynamic>[];

    final List<Instrument> out = <Instrument>[];
    for (final dynamic raw in quotes) {
      final Map<String, dynamic> q = raw as Map<String, dynamic>;
      final String? symbol = q['symbol'] as String?;
      final String? type = q['quoteType'] as String?;
      if (symbol == null) continue;
      // Options, futures and currencies need handling this app does not have.
      if (type != 'EQUITY' && type != 'INDEX' && type != 'ETF') continue;

      final String exchange = (q['exchange'] as String?) ?? '';
      final bool indian = symbol.endsWith('.NS') ||
          symbol.endsWith('.BO') ||
          exchange == 'NSI' ||
          exchange == 'BSE';

      out.add(
        Instrument(
          id: 'yahoo:$symbol',
          symbol: symbol,
          name: (q['shortname'] as String?) ??
              (q['longname'] as String?) ??
              symbol,
          region:
              indian ? MarketRegion.indiaEquity : MarketRegion.usEquity,
          displaySymbol: symbol.replaceAll(RegExp(r'\.(NS|BO)$'), ''),
          isIndex: type == 'INDEX',
        ),
      );
    }
    return out;
  }

  Future<Map<String, dynamic>> _chart(
    Instrument instrument, {
    required Map<String, String> params,
  }) async {
    // Uri.https encodes the path itself; pre-encoding '^' gave %255E and a
    // 404 when the importer first tried it.
    final Uri uri =
        _endpoint('/v8/finance/chart/${instrument.symbol}', params);

    final Object? json = await fetchJson(
      _client,
      uri,
      headers: <String, String>{'User-Agent': kBrowserUserAgent},
      sourceName: 'Yahoo Finance',
    );

    final Map<String, dynamic> chart =
        (json as Map<String, dynamic>)['chart'] as Map<String, dynamic>;

    final Map<String, dynamic>? error =
        chart['error'] as Map<String, dynamic>?;
    if (error != null) {
      throw MarketDataException(
        'Yahoo Finance: ${error['description'] ?? error['code']}',
      );
    }

    final List<dynamic>? results = chart['result'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      throw MarketDataException(
        'No data for ${instrument.ticker} in that range.',
      );
    }
    return results.first as Map<String, dynamic>;
  }

  static List<Candle> _candlesFrom(Map<String, dynamic> result) {
    final List<dynamic>? stamps = result['timestamp'] as List<dynamic>?;
    if (stamps == null) return const <Candle>[];

    final List<dynamic> quoteList =
        (result['indicators'] as Map<String, dynamic>)['quote']
            as List<dynamic>;
    if (quoteList.isEmpty) return const <Candle>[];

    final Map<String, dynamic> q = quoteList[0] as Map<String, dynamic>;
    final List<dynamic> o = q['open'] as List<dynamic>;
    final List<dynamic> h = q['high'] as List<dynamic>;
    final List<dynamic> l = q['low'] as List<dynamic>;
    final List<dynamic> c = q['close'] as List<dynamic>;
    final List<dynamic>? v = q['volume'] as List<dynamic>?;

    final List<Candle> out = <Candle>[];
    for (int i = 0; i < stamps.length; i++) {
      // Yahoo returns nulls for non-trading slots inside the range.
      if (o[i] == null || h[i] == null || l[i] == null || c[i] == null) {
        continue;
      }
      out.add(
        Candle(
          date: DateTime.fromMillisecondsSinceEpoch(
            (stamps[i] as num).toInt() * 1000,
            isUtc: true,
          ),
          open: (o[i] as num).toDouble(),
          high: (h[i] as num).toDouble(),
          low: (l[i] as num).toDouble(),
          close: (c[i] as num).toDouble(),
          volume: v == null || v[i] == null
              ? null
              : (v[i] as num).toDouble(),
        ),
      );
    }
    return out;
  }

  @override
  void dispose() => _client.close();
}
