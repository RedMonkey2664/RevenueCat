import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/market/instrument.dart';
import '../../chart/model/chart_labels.dart';

/// One row of the watchlist.
class QuoteTile extends StatelessWidget {
  const QuoteTile({
    required this.instrument,
    required this.quote,
    required this.onTap,
    this.loading = false,
    super.key,
  });

  final Instrument instrument;

  /// Null while loading, or when this one symbol failed.
  final Quote? quote;

  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final Quote? q = quote;
    final Color changeColor =
        q == null ? AppColors.textFaint : (q.isUp ? AppColors.up : AppColors.down);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          instrument.ticker,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.mono(
                            size: 14,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _RegionChip(region: instrument.region),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    instrument.name,
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
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  q == null
                      ? (loading ? '···' : '—')
                      : '${instrument.currencySymbol}'
                          '${formatPrice(q.price)}',
                  style: AppText.mono(size: 14, weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  q == null
                      ? (loading ? '' : 'unavailable')
                      : '${q.isUp ? '+' : ''}'
                          '${q.changePercent.toStringAsFixed(2)}%',
                  style: AppText.mono(
                    size: 11,
                    weight: FontWeight.w600,
                    color: changeColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RegionChip extends StatelessWidget {
  const _RegionChip({required this.region});

  final MarketRegion region;

  @override
  Widget build(BuildContext context) {
    final bool open = region.isOpenAt(DateTime.now().toUtc());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(
          color: open ? AppColors.up.withValues(alpha: 0.5) : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        region.label.toUpperCase(),
        style: AppText.label(
          size: 8,
          color: open ? AppColors.up : AppColors.textFaint,
        ),
      ),
    );
  }
}
