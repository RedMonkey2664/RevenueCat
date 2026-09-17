import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../app/widgets/feed_state.dart';
import '../../../core/market/instrument.dart';
import '../../chart/model/chart_labels.dart';

/// One row of the watchlist, in the feed-state grammar of artboard 1l:
/// loading hatches the value only, a live or delayed price always names its
/// source, and a failed feed keeps the label and dashes the number.
class QuoteTile extends StatelessWidget {
  const QuoteTile({
    required this.instrument,
    required this.quote,
    required this.onTap,
    this.onRetry,
    this.loading = false,
    super.key,
  });

  final Instrument instrument;

  /// Null while loading, or when this one symbol failed.
  final Quote? quote;

  final VoidCallback onTap;
  final VoidCallback? onRetry;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final Quote? q = quote;

    if (q == null && !loading) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: GestureDetector(
          onTap: onTap,
          child: FeedUnavailableRow(title: instrument.ticker, onRetry: onRetry),
        ),
      );
    }

    final bool delayed = q?.source.toLowerCase().contains('delayed') ?? false;
    final Color changeColor = q == null
        ? AppColors.textFaint
        : (q.isUp ? AppColors.up : AppColors.down);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md + 2,
          vertical: AppSpacing.md - 2,
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
                          style: AppText.railLabel(
                            size: 16,
                            weight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            letterSpacing: 16 * 0.08,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _RegionChip(region: instrument.region),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    instrument.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label(size: 10, color: AppColors.textFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (q == null)
                  const FeedLoadingValue(width: 104, height: 20)
                else
                  Text(
                    '${instrument.currencySymbol}${formatPrice(q.price)}',
                    style: AppText.display(
                      size: 19,
                      // Live cyan, delayed amber — the colour itself says how
                      // fresh the number is (artboard 1l).
                      color: delayed ? AppColors.caution : AppColors.data,
                    ),
                  ),
                const SizedBox(height: 4),
                if (q != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '${q.isUp ? '+' : ''}${q.changePercent.toStringAsFixed(2)}%',
                        style: AppText.mono(
                          size: 11,
                          weight: FontWeight.w600,
                          color: changeColor,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      SourceTag.fromAttribution(
                        q.source,
                        age: q.ageAt(DateTime.now()),
                      ),
                    ],
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
