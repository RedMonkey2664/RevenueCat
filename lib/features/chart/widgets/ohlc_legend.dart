import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../simulator/engine/candle_model.dart';
import '../model/chart_labels.dart';
import '../model/chart_types.dart';

/// The floating OHLC readout in the chart's top-left corner.
///
/// Shows the crosshair's bar when one is up, and the newest bar otherwise —
/// so the numbers are never blank and never stale.
class OhlcLegend extends StatelessWidget {
  const OhlcLegend({
    required this.bar,
    required this.previous,
    required this.labels,
    this.title,
    this.indicatorLegend = const <String>[],
    super.key,
  });

  final Candle? bar;

  /// The bar before [bar], for the change column. Null at the series start.
  final Candle? previous;

  final ChartLabels labels;

  /// Instrument name or, in blind mode, whatever the host is willing to show.
  final String? title;

  final List<String> indicatorLegend;

  @override
  Widget build(BuildContext context) {
    final Candle? c = bar;
    if (c == null) return const SizedBox.shrink();

    final double? change =
        previous == null ? null : (c.close / previous!.close - 1) * 100;
    final Color changeColor = (change ?? 0) >= 0
        ? AppColors.up
        : AppColors.down;

    return DefaultTextStyle(
      style: AppText.mono(size: 9, color: AppColors.textSecondary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                title!,
                style: AppText.label(color: AppColors.textPrimary, size: 10),
              ),
            ),
          Wrap(
            spacing: 8,
            children: <Widget>[
              _field('O', c.open),
              _field('H', c.high),
              _field('L', c.low),
              _field('C', c.close),
              if (change != null)
                Text(
                  '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%',
                  style: AppText.mono(
                    size: 9,
                    weight: FontWeight.w700,
                    color: changeColor,
                  ),
                ),
            ],
          ),
          if (c.volume != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('VOL ${formatVolume(c.volume!)}'),
            ),
          if (indicatorLegend.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                indicatorLegend.join('  ·  '),
                style: AppText.mono(size: 9, color: AppColors.textFaint),
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(String label, double value) {
    return RichText(
      text: TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '$label ',
            style: AppText.mono(size: 9, color: AppColors.textFaint),
          ),
          TextSpan(
            text: labels.price(value),
            style: AppText.mono(size: 9, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// Convenience: the intervals a host can offer given one base interval and
/// whether it can refetch.
///
/// Bundled-data hosts (campaign levels) can only fold daily bars upward, so
/// they must not advertise 5m. Live hosts advertise everything their provider
/// supports.
List<BarInterval> intervalsFor(
  BarInterval base, {
  List<BarInterval>? fetchable,
}) {
  final Set<BarInterval> out = <BarInterval>{base};
  for (final BarInterval i in BarInterval.values) {
    if (base.canAggregateTo(i)) out.add(i);
  }
  if (fetchable != null) out.addAll(fetchable);
  final List<BarInterval> sorted = out.toList()
    ..sort((BarInterval a, BarInterval b) => a.index.compareTo(b.index));
  return sorted;
}
