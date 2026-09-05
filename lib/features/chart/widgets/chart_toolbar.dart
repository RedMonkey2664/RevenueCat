import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../model/chart_types.dart';
import 'indicator_sheet.dart';

/// The chart's control strip.
///
/// Every control here is load-bearing — there is no inert chrome in this
/// toolbar. Anything the host cannot support is *absent*, not shown disabled:
/// a level with no intraday data simply does not list 5m, rather than
/// offering a button that explains itself after you tap it.
class ChartToolbar extends StatelessWidget {
  const ChartToolbar({
    required this.settings,
    required this.onChanged,
    required this.availableIntervals,
    this.onClearDrawings,
    this.drawingCount = 0,
    this.dense = false,
    this.showScaleToggle = true,
    super.key,
  });

  final ChartSettings settings;
  final ValueChanged<ChartSettings> onChanged;

  /// Which timeframes this host can actually serve.
  final List<BarInterval> availableIntervals;

  final VoidCallback? onClearDrawings;
  final int drawingCount;

  /// Drops the timeframe row — used where vertical space is tight.
  final bool dense;

  /// False during a blind-mode run. The scale is pinned to percent there so
  /// the gridlines land on round moves; offering Linear would only produce an
  /// axis of odd index values, since [ChartLabels] rebases either way.
  final bool showScaleToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (!dense && availableIntervals.length > 1) _intervalRow(),
        _toolRow(context),
      ],
    );
  }

  Widget _intervalRow() {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: <Widget>[
          for (final BarInterval i in availableIntervals)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: _Chip(
                label: i.label,
                selected: settings.interval == i,
                semanticLabel: i.longLabel,
                onTap: () => onChanged(settings.copyWith(interval: i)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _toolRow(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: <Widget>[
          _IconControl(
            icon: _iconForType(settings.chartType),
            tooltip: settings.chartType.label,
            onTap: () => _pickChartType(context),
          ),
          const _Divider(),
          _IconControl(
            icon: Icons.functions,
            tooltip: 'Indicators',
            badge: settings.indicators.isEmpty
                ? null
                : '${settings.indicators.length}',
            active: settings.indicators.isNotEmpty,
            onTap: () => _pickIndicators(context),
          ),
          const _Divider(),
          for (final ChartTool tool in ChartTool.values)
            _IconControl(
              icon: _iconForTool(tool),
              tooltip: tool.label,
              active: settings.tool == tool,
              onTap: () => onChanged(settings.copyWith(tool: tool)),
            ),
          const Spacer(),
          if (drawingCount > 0 && onClearDrawings != null)
            _IconControl(
              icon: Icons.layers_clear_outlined,
              tooltip: 'Clear $drawingCount drawing'
                  '${drawingCount == 1 ? '' : 's'}',
              onTap: onClearDrawings,
            ),
          if (showScaleToggle)
            _Chip(
              label: settings.scale.label,
              selected: settings.scale != PriceScale.linear,
              semanticLabel: '${settings.scale.label} price scale',
              onTap: () {
                const List<PriceScale> order = PriceScale.values;
                final int next =
                    (order.indexOf(settings.scale) + 1) % order.length;
                onChanged(settings.copyWith(scale: order[next]));
              },
            ),
        ],
      ),
    );
  }

  Future<void> _pickChartType(BuildContext context) async {
    final ChartType? picked = await showModalBottomSheet<ChartType>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text('CHART TYPE', style: AppText.label()),
            const SizedBox(height: AppSpacing.sm),
            for (final ChartType t in ChartType.values)
              ListTile(
                leading: Icon(
                  _iconForType(t),
                  color: settings.chartType == t
                      ? AppColors.accent
                      : AppColors.textSecondary,
                ),
                title: Text(t.label, style: AppText.body(size: 14)),
                trailing: settings.chartType == t
                    ? const Icon(Icons.check, color: AppColors.accent)
                    : null,
                onTap: () => Navigator.of(context).pop(t),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (picked != null) onChanged(settings.copyWith(chartType: picked));
  }

  Future<void> _pickIndicators(BuildContext context) async {
    final List<IndicatorSpec>? picked = await showModalBottomSheet<
        List<IndicatorSpec>>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) =>
          IndicatorSheet(selected: settings.indicators),
    );
    if (picked != null) onChanged(settings.copyWith(indicators: picked));
  }

  static IconData _iconForType(ChartType t) => switch (t) {
        ChartType.candles => Icons.candlestick_chart,
        ChartType.heikinAshi => Icons.view_week,
        ChartType.line => Icons.show_chart,
        ChartType.area => Icons.area_chart,
      };

  static IconData _iconForTool(ChartTool t) => switch (t) {
        ChartTool.cursor => Icons.near_me_outlined,
        ChartTool.trendline => Icons.timeline,
        ChartTool.horizontalLine => Icons.horizontal_rule,
        ChartTool.rectangle => Icons.crop_square,
      };
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.semanticLabel,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: semanticLabel ?? label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minWidth: 38),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10),
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
              color:
                  selected ? AppColors.accent : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconControl extends StatelessWidget {
  const _IconControl({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.badge,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: active,
        label: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: SizedBox(
            width: kMinTouchTarget,
            height: kMinTouchTarget,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Icon(
                  icon,
                  size: 19,
                  color:
                      active ? AppColors.accent : AppColors.textSecondary,
                ),
                if (badge != null)
                  Positioned(
                    right: 6,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 1,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.all(Radius.circular(3)),
                      ),
                      child: Text(
                        badge!,
                        style: AppText.mono(
                          size: 7,
                          weight: FontWeight.w700,
                          color: AppColors.background,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 18,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        color: AppColors.border,
      );
}
