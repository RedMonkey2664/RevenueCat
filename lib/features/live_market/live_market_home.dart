import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/market/instrument.dart';
import '../../core/market/market_data_service.dart';
import 'broker_connect_screen.dart';
import 'instrument_detail_screen.dart';
import 'services/live_quotes.dart';
import 'services/watchlist_service.dart';
import 'widgets/instrument_search_sheet.dart';
import 'widgets/quote_tile.dart';

/// Live Markets — a watchlist of real, current prices.
///
/// The one screen in the app showing numbers that are neither historical nor
/// simulated, which is exactly why it carries no SIMULATED badge and the
/// Simulator's screens do. Keeping that distinction unmistakable is the point
/// of DESIGN.md's framing rules: a user must never be unsure which of the two
/// they are looking at.
///
/// Nothing here places an order or implies one can be placed. It is a price
/// display and a doorway into the Custom Simulation.
class LiveMarketHome extends ConsumerStatefulWidget {
  const LiveMarketHome({super.key});

  @override
  ConsumerState<LiveMarketHome> createState() => _LiveMarketHomeState();
}

class _LiveMarketHomeState extends ConsumerState<LiveMarketHome>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(liveQuotesProvider.notifier).setPolling(true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Never poll a market API in the background.
    ref
        .read(liveQuotesProvider.notifier)
        .setPolling(state == AppLifecycleState.resumed);
  }

  Future<void> _addSymbol() async {
    final List<Instrument> current = ref.read(watchlistProvider);
    final Instrument? picked = await showModalBottomSheet<Instrument>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => InstrumentSearchSheet(
        service: ref.read(marketDataServiceProvider),
        alreadyAdded: <String>{
          for (final Instrument i in current) i.id,
        },
      ),
    );
    if (picked != null) {
      await ref.read(watchlistProvider.notifier).add(picked);
    }
  }

  void _open(Instrument instrument) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InstrumentDetailScreen(instrument: instrument),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Instrument> watchlist = ref.watch(watchlistProvider);
    final LiveQuotesState quotes = ref.watch(liveQuotesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'LIVE MARKETS',
          style: AppText.label(color: AppColors.textPrimary),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Connect a broker',
            icon: const Icon(Icons.link, size: 20),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const BrokerConnectScreen(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Add symbol',
            icon: const Icon(Icons.add, size: 22),
            onPressed: _addSymbol,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _StatusStrip(state: quotes),
          Expanded(
            child: watchlist.isEmpty
                ? _EmptyWatchlist(onAdd: _addSymbol)
                : RefreshIndicator(
                    color: AppColors.accent,
                    backgroundColor: AppColors.surfaceRaised,
                    onRefresh: () => ref
                        .read(liveQuotesProvider.notifier)
                        .refresh(force: true),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: watchlist.length,
                      itemBuilder: (BuildContext context, int i) {
                        final Instrument instrument = watchlist[i];
                        return Dismissible(
                          key: ValueKey<String>(instrument.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(
                              right: AppSpacing.md,
                            ),
                            color: AppColors.down.withValues(alpha: 0.18),
                            child: const Icon(
                              Icons.delete_outline,
                              color: AppColors.down,
                              size: 20,
                            ),
                          ),
                          onDismissed: (_) => ref
                              .read(watchlistProvider.notifier)
                              .remove(instrument),
                          child: QuoteTile(
                            instrument: instrument,
                            quote: quotes.quotes[instrument.id],
                            loading: quotes.loading,
                            onTap: () => _open(instrument),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          const _LiveDataDisclosure(),
        ],
      ),
    );
  }
}

/// Last-updated line, plus any whole-service error.
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.state});

  final LiveQuotesState state;

  @override
  Widget build(BuildContext context) {
    final DateTime? at = state.updatedAt;
    final String label = state.error != null
        ? state.error!
        : at == null
            ? 'Fetching prices…'
            : 'Updated ${_clock(at)} · refreshes every '
                '${LiveQuotes.interval.inSeconds}s';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: <Widget>[
          if (state.loading)
            const SizedBox(
              width: 9,
              height: 9,
              child: CircularProgressIndicator(
                strokeWidth: 1.4,
                color: AppColors.accent,
              ),
            )
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: state.error != null ? AppColors.down : AppColors.up,
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label(
                size: 9,
                color: state.error != null
                    ? AppColors.down
                    : AppColors.textFaint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';
}

/// The counterpart to the Simulator's SIMULATED badge.
///
/// CLAUDE.md requires every screen touching virtual money to be unmistakably
/// simulated. This screen is the inverse case and needs the opposite label:
/// these prices are real, they are not tradeable here, and they may be
/// delayed. Saying so is what keeps the SIMULATED badge meaningful elsewhere.
class _LiveDataDisclosure extends StatelessWidget {
  const _LiveDataDisclosure();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Text(
          'Real market prices, for reference only. Equity prices may be '
          'delayed. No orders can be placed in this app.',
          style: AppText.body(size: 10.5, color: AppColors.textFaint),
        ),
      ),
    );
  }
}

class _EmptyWatchlist extends StatelessWidget {
  const _EmptyWatchlist({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('WATCHLIST', style: AppText.label()),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Nothing here yet',
              style: AppText.mono(size: 18, weight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Add an index, a stock or a crypto pair to follow it live.',
              textAlign: TextAlign.center,
              style: AppText.body(size: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add a symbol'),
            ),
          ],
        ),
      ),
    );
  }
}
