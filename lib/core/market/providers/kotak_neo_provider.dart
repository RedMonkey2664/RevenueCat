import 'package:http/http.dart' as http;

import '../bar_interval.dart';
import '../broker_credentials.dart';
import '../candle.dart';
import '../instrument.dart';
import '../market_data_provider.dart';

/// Kotak Neo — real-time NSE/BSE data from the user's own broker account.
///
/// ## Status: structurally complete, wire calls not yet implemented
///
/// Everything around the network layer is finished and in use: credential
/// storage ([BrokerCredentialStore]), the session model, the connect screen,
/// provider registration and the ready/not-ready gating that keeps this out
/// of the way until it can actually serve data. What is deliberately NOT here
/// is invented endpoint paths.
///
/// CLAUDE.md: *"When a spec file is ambiguous or missing data, stop and ask
/// rather than inventing facts."* Kotak Neo's request/response shapes are not
/// something to guess at — a wrong path or field name would fail at runtime,
/// on a real user's brokerage account, in a way that looks like a bug in this
/// app rather than a missing spec. So each network method throws a clear
/// [MarketDataException] until the real calls are filled in.
///
/// ## What is needed to finish it
///
/// 1. Consumer key + secret from Kotak's developer portal (Somi is getting
///    these).
/// 2. The current API documentation, for four calls:
///    - OAuth token exchange from the consumer key/secret
///    - login with mobile + password, returning a view token
///    - OTP/TOTP validation, returning the final session token
///    - quotes and historical candles for a scrip
/// 3. The scrip-master mapping, since Kotak addresses instruments by an
///    internal token rather than by ticker — [Instrument.symbol] will need a
///    Kotak-specific id, which is exactly why [Instrument.id] is decoupled
///    from the ticker.
///
/// Each is a body for one of the methods below. Nothing outside this file
/// changes: [MarketDataService] already routes by region and falls back
/// automatically while [isReady] is false.
///
/// ## Scope note
///
/// Kotak Neo covers NSE/BSE only, so this can never serve US equity or
/// crypto — those stay on their existing providers permanently.
class KotakNeoProvider extends MarketDataProvider {
  KotakNeoProvider({
    required BrokerCredentials? credentials,
    required BrokerSession? session,
    http.Client? client,
  })  : _credentials = credentials,
        _session = session,
        _client = client ?? http.Client();

  final BrokerCredentials? _credentials;
  final BrokerSession? _session;
  // ignore: unused_field — used by the network calls once implemented.
  final http.Client _client;

  @override
  String get id => 'kotak_neo';

  @override
  String get displayName => 'Kotak Neo';

  @override
  Set<MarketRegion> get regions => <MarketRegion>{MarketRegion.indiaEquity};

  @override
  bool get isReady => false;

  @override
  String? get notReadyReason {
    if (_credentials == null || !_credentials.isComplete) {
      return 'Add your Kotak Neo consumer key and secret to connect.';
    }
    if (_session == null || !_session.isValid) {
      return 'Sign in to Kotak Neo to use live NSE/BSE prices.';
    }
    return 'Kotak Neo support is not finished — the API calls still need the '
        'official endpoint specification. Indian prices are coming from the '
        'fallback source in the meantime.';
  }

  @override
  bool get isDelayed => false;

  @override
  List<BarInterval> intervalsFor(Instrument instrument) => const <BarInterval>[
        BarInterval.m1,
        BarInterval.m5,
        BarInterval.m15,
        BarInterval.m30,
        BarInterval.h1,
        BarInterval.d1,
      ];

  @override
  Duration maxHistoryFor(BarInterval interval) =>
      interval.isIntraday
          ? const Duration(days: 30)
          : const Duration(days: 365 * 5);

  static const MarketDataException _notImplemented = MarketDataException(
    'Kotak Neo is not connected yet. Live Indian prices are using the '
    'fallback source.',
    isAuthProblem: true,
  );

  @override
  Future<Quote> quote(Instrument instrument) async => throw _notImplemented;

  @override
  Future<List<Candle>> history(
    Instrument instrument, {
    required BarInterval interval,
    DateTime? from,
    DateTime? to,
  }) async =>
      throw _notImplemented;

  @override
  void dispose() => _client.close();
}
