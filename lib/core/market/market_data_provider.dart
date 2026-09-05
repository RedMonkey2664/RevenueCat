import 'bar_interval.dart';
import 'candle.dart';
import 'instrument.dart';

/// Raised when market data genuinely cannot be fetched.
///
/// Never swallowed into a fallback number. CLAUDE.md forbids presenting an
/// invented figure as fact, and a silently stale or guessed live price is
/// exactly that — worse here than in the Simulator, because the user may act
/// on it.
class MarketDataException implements Exception {
  const MarketDataException(this.message, {this.isAuthProblem = false});

  final String message;

  /// True when the fix is "connect/reconnect your broker", not "try again".
  final bool isAuthProblem;

  @override
  String toString() => message;
}

/// A source of live quotes and historical bars.
///
/// Implemented by the keyless public sources the app ships with, and by the
/// Kotak Neo broker client once a user connects one. The rest of the app
/// talks to [MarketDataService], never to a provider directly, so swapping
/// the source behind a market is a one-line registration change.
abstract class MarketDataProvider {
  /// Stable id, used in cache keys and in the on-screen attribution.
  String get id;

  /// What the UI calls this source, e.g. "Yahoo Finance (delayed)".
  String get displayName;

  /// Markets this provider can serve.
  Set<MarketRegion> get regions;

  /// False when the provider exists but cannot be used yet — Kotak Neo with
  /// no credentials, for instance. [notReadyReason] then explains it in
  /// words a user can act on.
  bool get isReady;

  String? get notReadyReason;

  /// Whether prices are delayed rather than real-time. Surfaced in the UI:
  /// showing a 15-minute-old price as "live" would be a lie.
  bool get isDelayed;

  /// Intervals this provider can fetch natively for [instrument].
  List<BarInterval> intervalsFor(Instrument instrument);

  /// How far back [interval] can be requested. Providers cap intraday
  /// history hard — Yahoo gives 1m for about a week — and asking beyond it
  /// returns an empty series rather than an error, so the caller has to know
  /// the limit up front.
  Duration maxHistoryFor(BarInterval interval);

  Future<Quote> quote(Instrument instrument);

  /// Batched quotes. The default is a sequential fan-out; providers with a
  /// real batch endpoint override it.
  Future<List<Quote>> quotes(List<Instrument> instruments) async {
    final List<Quote> out = <Quote>[];
    for (final Instrument i in instruments) {
      out.add(await quote(i));
    }
    return out;
  }

  /// Historical bars, oldest first.
  ///
  /// [from] and [to] are inclusive calendar bounds. Providers clamp to their
  /// own limits and return what they have rather than throwing, except when
  /// the request is impossible ([interval] unsupported, symbol unknown).
  Future<List<Candle>> history(
    Instrument instrument, {
    required BarInterval interval,
    DateTime? from,
    DateTime? to,
  });

  /// Free-text symbol search. Returns an empty list when the provider has no
  /// search endpoint; [MarketDataService] falls back to the bundled catalog.
  Future<List<Instrument>> search(String query) async => const <Instrument>[];

  void dispose() {}
}
