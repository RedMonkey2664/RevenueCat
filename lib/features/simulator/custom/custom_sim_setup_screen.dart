import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/market/bar_interval.dart';
import '../../../core/market/candle.dart';
import '../../../core/market/instrument.dart';
import '../../../core/market/market_data_provider.dart';
import '../../../core/market/market_data_service.dart';
import '../../live_market/widgets/instrument_search_sheet.dart';
import '../engine/level_model.dart';
import '../engine/simulation_mode.dart';
import '../level/level_screen.dart';
import 'custom_sim_builder.dart';

/// Build a simulation over any instrument and any date range.
///
/// The bridge between the two new features: Live Markets says what a price is
/// doing now, this replays what it *did* and makes you trade it.
///
/// Everything inside the run is still simulated — virtual capital, no orders,
/// the same engine and the same Discipline Score as a campaign level. Only
/// the price data is real and freshly fetched rather than bundled.
class CustomSimSetupScreen extends ConsumerStatefulWidget {
  const CustomSimSetupScreen({this.instrument, super.key});

  /// Pre-selected when arriving from an instrument's chart.
  final Instrument? instrument;

  @override
  ConsumerState<CustomSimSetupScreen> createState() =>
      _CustomSimSetupScreenState();
}

class _CustomSimSetupScreenState
    extends ConsumerState<CustomSimSetupScreen> {
  Instrument? _instrument;
  BarInterval _interval = BarInterval.d1;
  SimulationMode _mode = SimulationMode.advanced;

  late DateTime _to;
  late DateTime _from;

  bool _busy = false;
  String? _error;

  /// The presets that make the common case one tap.
  static const List<({String label, Duration back})> _presets =
      <({String label, Duration back})>[
    (label: '1 month', back: Duration(days: 30)),
    (label: '3 months', back: Duration(days: 91)),
    (label: '6 months', back: Duration(days: 182)),
    (label: '1 year', back: Duration(days: 365)),
    (label: '2 years', back: Duration(days: 730)),
    (label: '5 years', back: Duration(days: 1826)),
  ];

  @override
  void initState() {
    super.initState();
    _instrument = widget.instrument;
    _to = _today();
    // The example Somi asked for — six months back to today — is the default.
    _from = _to.subtract(const Duration(days: 182));
  }

  static DateTime _today() {
    final DateTime n = DateTime.now().toUtc();
    return DateTime.utc(n.year, n.month, n.day);
  }

  Future<void> _pickInstrument() async {
    final Instrument? picked = await showModalBottomSheet<Instrument>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => InstrumentSearchSheet(
        service: ref.read(marketDataServiceProvider),
        alreadyAdded: const <String>{},
      ),
    );
    if (picked != null) {
      setState(() {
        _instrument = picked;
        _error = null;
        // Intraday support varies by provider; fall back to daily rather than
        // carrying an interval the new instrument cannot serve.
        if (!ref
            .read(marketDataServiceProvider)
            .intervalsFor(picked)
            .contains(_interval)) {
          _interval = BarInterval.d1;
        }
      });
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final DateTime initial = isStart ? _from : _to;
    final DateTime picked0 = initial;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: picked0,
      firstDate: DateTime.utc(1990),
      lastDate: _today(),
    );
    if (picked == null) return;

    setState(() {
      final DateTime day = DateTime.utc(picked.year, picked.month, picked.day);
      if (isStart) {
        _from = day;
        if (!_from.isBefore(_to)) _to = _from.add(const Duration(days: 30));
        if (_to.isAfter(_today())) _to = _today();
      } else {
        _to = day;
        if (!_from.isBefore(_to)) {
          _from = _to.subtract(const Duration(days: 30));
        }
      }
      _error = null;
    });
  }

  void _applyPreset(Duration back) {
    setState(() {
      _to = _today();
      _from = _to.subtract(back);
      _error = null;
    });
  }

  Future<void> _start() async {
    final Instrument? instrument = _instrument;
    if (instrument == null) {
      setState(() => _error = 'Pick an instrument first.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final MarketDataService service = ref.read(marketDataServiceProvider);
    final NavigatorState navigator = Navigator.of(context);

    try {
      final BarInterval native =
          service.nativeIntervalFor(instrument, _interval);
      final Duration cap = service.maxHistoryFor(instrument, native);
      final DateTime earliest = _to.subtract(cap);

      if (_from.isBefore(earliest)) {
        throw CustomSimException(
          '${service.sourceLabelFor(instrument)} only keeps '
          '${_interval.longLabel} bars for about ${cap.inDays} days. '
          'Move the start date forward, or use a coarser timeframe.',
        );
      }

      final List<Candle> bars = await service.history(
        instrument,
        interval: native,
        from: _from,
        to: _to,
      );

      final SimulationLevel level = CustomSimBuilder.build(
        instrument: instrument,
        candles: bars,
        interval: _interval,
        from: _from,
        to: _to,
      );

      if (!mounted) return;
      setState(() => _busy = false);

      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => LevelScreen(level: level, mode: _mode),
        ),
      );
    } on CustomSimException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } on MarketDataException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Instrument? instrument = _instrument;
    final MarketDataService service = ref.watch(marketDataServiceProvider);
    final List<BarInterval> intervals = instrument == null
        ? const <BarInterval>[BarInterval.d1]
        : service.intervalsFor(instrument);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'CUSTOM SIMULATION',
          style: AppText.label(color: AppColors.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          Text(
            'Replay any instrument over any window, and trade it as the bars '
            'arrive. Real historical prices, virtual money.',
            style: AppText.body(size: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),

          _section('INSTRUMENT'),
          _Field(
            onTap: _pickInstrument,
            child: instrument == null
                ? Text(
                    'Choose an instrument',
                    style: AppText.body(
                      size: 14,
                      color: AppColors.textFaint,
                    ),
                  )
                : Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              instrument.ticker,
                              style: AppText.mono(
                                size: 14,
                                weight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${instrument.name} · '
                              '${instrument.region.label}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body(
                                size: 11,
                                color: AppColors.textFaint,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.textFaint,
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: AppSpacing.lg),
          _section('RANGE'),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final ({String label, Duration back}) p in _presets)
                _Pill(
                  label: p.label,
                  selected: _to.difference(_from).inDays == p.back.inDays &&
                      _to == _today(),
                  onTap: () => _applyPreset(p.back),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: _Field(
                  onTap: () => _pickDate(isStart: true),
                  child: _dateLabel('FROM', _from),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Field(
                  onTap: () => _pickDate(isStart: false),
                  child: _dateLabel('TO', _to),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),
          _section('TIMEFRAME'),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final BarInterval i in intervals)
                _Pill(
                  label: i.label,
                  selected: _interval == i,
                  onTap: () => setState(() {
                    _interval = i;
                    _error = null;
                  }),
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),
          _section('HOW YOU PLAY'),
          RadioGroup<SimulationMode>(
            groupValue: _mode,
            onChanged: (SimulationMode? v) =>
                setState(() => _mode = v ?? _mode),
            child: Column(
              children: <Widget>[
                for (final SimulationMode m in SimulationMode.values)
                  RadioListTile<SimulationMode>(
                    value: m,
                    activeColor: AppColors.accent,
                    contentPadding: EdgeInsets.zero,
                    title: Text(m.label, style: AppText.body(size: 13)),
                    subtitle: Text(
                      m.blurb,
                      style: AppText.body(
                        size: 11,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: AppColors.down.withValues(alpha: 0.10),
                border: Border.all(
                  color: AppColors.down.withValues(alpha: 0.4),
                ),
                borderRadius: AppRadius.chip,
              ),
              child: Text(
                _error!,
                style: AppText.body(size: 12, color: AppColors.down),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.background,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.chip,
                ),
              ),
              onPressed: _busy ? null : _start,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.background,
                      ),
                    )
                  : Text(
                      'Fetch data and start',
                      style: AppText.body(
                        size: 14,
                        weight: FontWeight.w700,
                        color: AppColors.background,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Prices are real and fetched live'
            '${instrument == null ? '' : ' from '
                '${service.sourceLabelFor(instrument)}'}. '
            'The trading is simulated with ₹1,00,000 of virtual capital — no '
            'orders are placed anywhere.',
            style: AppText.body(size: 11, color: AppColors.textFaint),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(label, style: AppText.label()),
      );

  Widget _dateLabel(String label, DateTime date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: AppText.label(size: 8)),
        const SizedBox(height: 2),
        Text(
          '${date.day.toString().padLeft(2, '0')} '
          '${_months[date.month - 1]} ${date.year}',
          style: AppText.mono(size: 13, weight: FontWeight.w600),
        ),
      ],
    );
  }

  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}

class _Field extends StatelessWidget {
  const _Field({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: kMinTouchTarget + 6),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 4,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: AppRadius.chip,
          color: AppColors.surface,
        ),
        child: child,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.14)
              : Colors.transparent,
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
          borderRadius: AppRadius.chip,
        ),
        child: Text(
          label,
          style: AppText.label(
            size: 10,
            color: selected ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
