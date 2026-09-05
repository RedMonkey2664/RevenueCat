import 'instrument.dart';

/// A bundled list of well-known instruments.
///
/// Two jobs: it seeds a new watchlist with something worth looking at, and it
/// makes symbol search work before (or without) a network round trip. Yahoo's
/// search endpoint supplements it for anything not listed here.
///
/// Tickers are the provider-native ones — Yahoo's `.NS` suffix for NSE
/// listings, Binance's `USDT` pairs. Nothing here is a price or a claim about
/// a value, so there is no sourcing burden; these are just symbols.
abstract final class InstrumentCatalog {
  static const List<Instrument> all = <Instrument>[
    // ---------------------------------------------------------- US equity
    Instrument(
      id: 'yahoo:^GSPC',
      symbol: '^GSPC',
      name: 'S&P 500',
      region: MarketRegion.usEquity,
      displaySymbol: 'SPX',
      isIndex: true,
    ),
    Instrument(
      id: 'yahoo:^IXIC',
      symbol: '^IXIC',
      name: 'Nasdaq Composite',
      region: MarketRegion.usEquity,
      displaySymbol: 'IXIC',
      isIndex: true,
    ),
    Instrument(
      id: 'yahoo:^DJI',
      symbol: '^DJI',
      name: 'Dow Jones Industrial Average',
      region: MarketRegion.usEquity,
      displaySymbol: 'DJI',
      isIndex: true,
    ),
    Instrument(
      id: 'yahoo:AAPL',
      symbol: 'AAPL',
      name: 'Apple Inc.',
      region: MarketRegion.usEquity,
    ),
    Instrument(
      id: 'yahoo:MSFT',
      symbol: 'MSFT',
      name: 'Microsoft Corporation',
      region: MarketRegion.usEquity,
    ),
    Instrument(
      id: 'yahoo:NVDA',
      symbol: 'NVDA',
      name: 'NVIDIA Corporation',
      region: MarketRegion.usEquity,
    ),
    Instrument(
      id: 'yahoo:TSLA',
      symbol: 'TSLA',
      name: 'Tesla, Inc.',
      region: MarketRegion.usEquity,
    ),
    Instrument(
      id: 'yahoo:AMZN',
      symbol: 'AMZN',
      name: 'Amazon.com, Inc.',
      region: MarketRegion.usEquity,
    ),
    Instrument(
      id: 'yahoo:GOOGL',
      symbol: 'GOOGL',
      name: 'Alphabet Inc.',
      region: MarketRegion.usEquity,
    ),
    Instrument(
      id: 'yahoo:META',
      symbol: 'META',
      name: 'Meta Platforms, Inc.',
      region: MarketRegion.usEquity,
    ),

    // ------------------------------------------------------- India equity
    Instrument(
      id: 'yahoo:^NSEI',
      symbol: '^NSEI',
      name: 'NIFTY 50',
      region: MarketRegion.indiaEquity,
      displaySymbol: 'NIFTY',
      isIndex: true,
    ),
    Instrument(
      id: 'yahoo:^BSESN',
      symbol: '^BSESN',
      name: 'BSE SENSEX',
      region: MarketRegion.indiaEquity,
      displaySymbol: 'SENSEX',
      isIndex: true,
    ),
    Instrument(
      id: 'yahoo:^NSEBANK',
      symbol: '^NSEBANK',
      name: 'NIFTY Bank',
      region: MarketRegion.indiaEquity,
      displaySymbol: 'BANKNIFTY',
      isIndex: true,
    ),
    Instrument(
      id: 'yahoo:RELIANCE.NS',
      symbol: 'RELIANCE.NS',
      name: 'Reliance Industries',
      region: MarketRegion.indiaEquity,
      displaySymbol: 'RELIANCE',
    ),
    Instrument(
      id: 'yahoo:TCS.NS',
      symbol: 'TCS.NS',
      name: 'Tata Consultancy Services',
      region: MarketRegion.indiaEquity,
      displaySymbol: 'TCS',
    ),
    Instrument(
      id: 'yahoo:HDFCBANK.NS',
      symbol: 'HDFCBANK.NS',
      name: 'HDFC Bank',
      region: MarketRegion.indiaEquity,
      displaySymbol: 'HDFCBANK',
    ),
    Instrument(
      id: 'yahoo:INFY.NS',
      symbol: 'INFY.NS',
      name: 'Infosys',
      region: MarketRegion.indiaEquity,
      displaySymbol: 'INFY',
    ),
    Instrument(
      id: 'yahoo:ICICIBANK.NS',
      symbol: 'ICICIBANK.NS',
      name: 'ICICI Bank',
      region: MarketRegion.indiaEquity,
      displaySymbol: 'ICICIBANK',
    ),
    Instrument(
      id: 'yahoo:SBIN.NS',
      symbol: 'SBIN.NS',
      name: 'State Bank of India',
      region: MarketRegion.indiaEquity,
      displaySymbol: 'SBIN',
    ),
    Instrument(
      id: 'yahoo:ITC.NS',
      symbol: 'ITC.NS',
      name: 'ITC Limited',
      region: MarketRegion.indiaEquity,
      displaySymbol: 'ITC',
    ),
    Instrument(
      id: 'yahoo:TATAMOTORS.NS',
      symbol: 'TATAMOTORS.NS',
      name: 'Tata Motors',
      region: MarketRegion.indiaEquity,
      displaySymbol: 'TATAMOTORS',
    ),

    // ------------------------------------------------------------- crypto
    Instrument(
      id: 'binance:BTCUSDT',
      symbol: 'BTCUSDT',
      name: 'Bitcoin',
      region: MarketRegion.crypto,
      displaySymbol: 'BTC/USDT',
    ),
    Instrument(
      id: 'binance:ETHUSDT',
      symbol: 'ETHUSDT',
      name: 'Ethereum',
      region: MarketRegion.crypto,
      displaySymbol: 'ETH/USDT',
    ),
    Instrument(
      id: 'binance:SOLUSDT',
      symbol: 'SOLUSDT',
      name: 'Solana',
      region: MarketRegion.crypto,
      displaySymbol: 'SOL/USDT',
    ),
    Instrument(
      id: 'binance:BNBUSDT',
      symbol: 'BNBUSDT',
      name: 'BNB',
      region: MarketRegion.crypto,
      displaySymbol: 'BNB/USDT',
    ),
    Instrument(
      id: 'binance:XRPUSDT',
      symbol: 'XRPUSDT',
      name: 'XRP',
      region: MarketRegion.crypto,
      displaySymbol: 'XRP/USDT',
    ),
    Instrument(
      id: 'binance:DOGEUSDT',
      symbol: 'DOGEUSDT',
      name: 'Dogecoin',
      region: MarketRegion.crypto,
      displaySymbol: 'DOGE/USDT',
    ),
  ];

  /// What a fresh install sees — one recognisable name per market, so the
  /// tab is useful before the user adds anything.
  static const List<String> defaultWatchlistIds = <String>[
    'yahoo:^NSEI',
    'binance:BTCUSDT',
    'yahoo:^GSPC',
    'yahoo:RELIANCE.NS',
  ];

  static Instrument? byId(String id) {
    for (final Instrument i in all) {
      if (i.id == id) return i;
    }
    return null;
  }

  static List<Instrument> forRegion(MarketRegion region) =>
      all.where((Instrument i) => i.region == region).toList();

  /// Case-insensitive match on ticker or name.
  static List<Instrument> search(String query, {MarketRegion? region}) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return region == null ? all : forRegion(region);
    }
    return all.where((Instrument i) {
      if (region != null && i.region != region) return false;
      return i.ticker.toLowerCase().contains(q) ||
          i.symbol.toLowerCase().contains(q) ||
          i.name.toLowerCase().contains(q);
    }).toList();
  }
}
