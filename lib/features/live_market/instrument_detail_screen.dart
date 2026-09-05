import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/market/candle.dart';
import '../../core/market/instrument.dart';
import '../../core/market/market_data_provider.dart';
import '../../core/market/market_data_service.dart';
import '../chart/model/chart_drawing.dart';
import '../chart/model/chart_labels.dart';
import '../chart/model/chart_types.dart';
import '../chart/pro_chart.dart';
import '../chart/services/chart_preferences.dart';
import '../chart/widgets/chart_toolbar.dart';
import '../chart/widgets/ohlc_legend.dart';
import '../simulator/custom/custom_sim_setup_screen.dart';
import 'services/live_quotes.dart';

/// One instrument, full chart.
///
/// The TradingView-shaped screen: quote header, interactive chart, toolbar,
/// and a route into the Custom Simulation over whatever range is on screen.
class InstrumentDetailScreen extends ConsumerStatefulWidget {
  const InstrumentDetailScreen({required this.instrument, super.key});

  final Instrument instrument;

  @override
  ConsumerState<InstrumentDetailScreen> createState() =>
      _InstrumentDetailScreenState();
}

class _InstrumentDetailScreenState
    extends ConsumerState<InstrumentDetailScreen> {
  late ChartSettings _settings;
  late List<ChartDrawing> _drawings;

  List<Candle> _bars = const <Candle>[];

  /// The interval the loaded bars are actually at, which is not always the
  /// one selected — Yahoo has no 4H bar, so 1H is fetched and folded.
  BarInterval _baseInterval = BarInterval.d1;

  bool _loading = true;
  String? _error;
  Candle? _hovered;

  /// Guards against an older, slower fetch overwriting a newer one when the
  /// user taps through several timeframes quickly.
  int _generation = 0;

  String get _chartId => 'live:${widget.instrument.id}';

  @override
  void initState() {
    super.initState();
    final ChartPreferences prefs = ref.read(chartPreferencesProvider);
    _settings = prefs.loadSettings(defaultInterval: BarInterval.d1);
    _drawings = prefs.loadDrawings(_chartId);
    _load();
  }

  /// How much history to request per timeframe.
  ///
  /// Enough to fill the screen and pan back a good way, without asking a
  /// free endpoint for ten years of one-minute bars.
  static Duration _rangeFor(BarInterval interval) => switch (interval) {
        BarInterval.m1 => const Duration(days: 5),
        BarInterval.m5 => const Duration(days: 20),
        BarInterval.m15 || BarInterval.m30 => const Duration(days: 60),
        BarInterval.h1 || BarInterval.h4 => const Duration(days: 240),
        BarInterval.d1 => const Duration(days: 365 * 3),
        BarInterval.w1 => const Duration(days: 365 * 10),
        BarInterval.mo1 => const Duration(days: 365 * 20),
      };

  Future<void> _load() async {
    final int generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });

    final MarketDataService service = ref.read(marketDataServiceProvider);
    final BarInterval wanted = _settings.interval;

    try {
      final BarInterval native =
          service.nativeIntervalFor(widget.instrument, wanted);
      final DateTime end = DateTime.now().toUtc();
      final Duration range = _rangeFor(wanted);
      final Duration cap = service.maxHistoryFor(widget.instrument, native);

      final List<Candle> bars = await service.history(
        widget.instrument,
        interval: native,
        from: end.subtract(range < cap ? range : cap),
        to: end,
      );

      if (!mounted || generation != _generation) return;
      setState(() {
        _bars = bars;
        _baseInterval = native;
        _loading = false;
        _error = bars.isEmpty
            ? 'No ${wanted.longLabel} data was returned for '
                '${widget.instrument.ticker}.'
            : null;
      });
    } on MarketDataException catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  void _applySettings(ChartSettings next) {
    final bool intervalChanged = next.interval != _settings.interval;
    setState(() => _settings = next);
    ref.read(chartPreferencesProvider).saveSettings(next);
    if (intervalChanged) _load();
  }

  void _applyDrawings(List<ChartDrawing> next) {
    setState(() => _drawings = next);
    ref.read(chartPreferencesProvider).saveDrawings(_chartId, next);
  }

  void _openCustomSim() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomSimSetupScreen(instrument: widget.instrument),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Instrument instrument = widget.instrument;
    final Quote? quote =
        ref.watch(liveQuotesProvider).quotes[instrument.id];
    final MarketDataService service = ref.watch(marketDataServiceProvider);

    final List<BarInterval> intervals = intervalsFor(
      _baseInterval,
      fetchable: service.intervalsFor(instrument),
    );

    final ChartLabels labels =
        RealChartLabels(currencySymbol: instrument.currencySymbol);

    final Candle? legendBar =
        _hovered ?? (_bars.isEmpty ? null : _bars.last);
    final int legendIndex =
        legendBar == null ? -1 : _bars.indexOf(legendBar);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              instrument.ticker,
              style: AppText.mono(size: 13, weight: FontWeight.w700),
            ),
            Text(
              instrument.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(size: 10, color: AppColors.textFaint),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _QuoteHeader(
            instrument: instrument,
            quote: quote,
            sourceLabel: service.sourceLabelFor(instrument),
          ),
          Expanded(
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.sm,
                      top: AppSpacing.xl + AppSpacing.sm,
                      bottom: AppSpacing.xs,
                    ),
                    child: _error != null
                        ? _ChartError(message: _error!, onRetry: _load)
                        : ProChart(
                            bars: _bars,
                            baseInterval: _baseInterval,
                            settings: _settings,
                            labels: labels,
                            drawings: _drawings,
                            onDrawingsChanged: _applyDrawings,
                            onCrosshairChanged: (Candle? c) =>
                                setState(() => _hovered = c),
                          ),
                  ),
                ),
                Positioned(
                  left: AppSpacing.sm + 4,
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: IgnorePointer(
                    child: OhlcLegend(
                      bar: legendBar,
                      previous: legendIndex > 0
                          ? _bars[legendIndex - 1]
                          : null,
                      labels: labels,
                      indicatorLegend: <String>[
                        for (final IndicatorSpec s in _settings.indicators)
                          s.label,
                      ],
                    ),
                  ),
                ),
                if (_loading)
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: LinearProgressIndicator(
                      minHeight: 1.5,
                      color: AppColors.accent,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
              ],
            ),
          ),
          ChartToolbar(
            settings: _settings,
            onChanged: _applySettings,
            availableIntervals: intervals,
            drawingCount: _drawings.length,
            onClearDrawings: () => _applyDrawings(const <ChartDrawing>[]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.background,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.chip,
                    ),
                  ),
                  onPressed: _openCustomSim,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(
                    'Simulate this instrument',
                    style: AppText.body(
                      size: 13,
                      weight: FontWeight.w600,
                      color: AppColors.background,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteHeader extends StatelessWidget {
  const _QuoteHeader({
    required this.instrument,
    required this.quote,
    required this.sourceLabel,
  });

  final Instrument instrument;
  final Quote? quote;
  final String sourceLabel;

  @override
  Widget build(BuildContext context) {
    final Quote? q = quote;
    final bool open = instrument.region.isOpenAt(DateTime.now().toUtc());
    final Color changeColor = q == null
        ? AppColors.textFaint
        : (q.isUp ? AppColors.up : AppColors.down);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                q == null
                    ? '—'
                    : '${instrument.currencySymbol}'
                        '${formatPrice(q.price)}',
                style: AppText.mono(size: 24, weight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              if (q != null)
                Text(
                  '${q.isUp ? '+' : ''}${formatPrice(q.change)}  '
                  '(${q.isUp ? '+' : ''}'
                  '${q.changePercent.toStringAsFixed(2)}%)',
                  style: AppText.mono(
                    size: 12,
                    weight: FontWeight.w600,
                    color: changeColor,
                  ),
                ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: open ? AppColors.up : AppColors.textFaint,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    open ? 'MARKET OPEN' : 'CLOSED',
                    style: AppText.label(
                      size: 9,
                      color: open ? AppColors.up : AppColors.textFaint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              // Attribution is not decoration: every live number in this app
              // has to be able to say where it came from.
              Text(
                sourceLabel,
                style: AppText.label(size: 8, color: AppColors.textFaint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartError extends StatelessWidget {
  const _ChartError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.textFaint,
              size: 28,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.body(size: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
