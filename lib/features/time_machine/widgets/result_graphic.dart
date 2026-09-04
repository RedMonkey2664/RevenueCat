import 'package:flutter/material.dart';

import '../../../app/formatting.dart';
import '../../../app/theme.dart';
import '../services/historical_price_lookup.dart';

/// The shareable card, at a fixed 9:16 for Instagram Stories.
///
/// This is the marketing unit (TIME_MACHINE.md), so the watermark and CTA are
/// baked into the pixels — not optional chrome.
///
/// It is rendered at a fixed logical size and scaled to fit, so the exported
/// image is identical on every device rather than reflowing with screen width.
class ResultGraphic extends StatelessWidget {
  const ResultGraphic({required this.result, super.key});

  /// Logical design size. 9:16.
  static const Size designSize = Size(1080, 1920);

  final TimeMachineResult result;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: SizedBox(
        width: designSize.width,
        height: designSize.height,
        child: _Card(result: result),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.result});

  final TimeMachineResult result;

  @override
  Widget build(BuildContext context) {
    final bool gained = result.isGain;
    final Color headline = gained ? AppColors.accent : AppColors.down;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF0D1117), Color(0xFF11202B)],
        ),
      ),
      child: Stack(
        children: <Widget>[
          // A wash of the accent behind the number, so the card reads as the
          // same product as the Simulator's debrief at a glance.
          Positioned(
            top: 380,
            left: -180,
            child: Container(
              width: 900,
              height: 900,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    headline.withValues(alpha: 0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(90, 110, 90, 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'MARKET NERVE',
                  style: AppText.mono(
                    size: 34,
                    weight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 8,
                  ),
                ),
                const Spacer(),
                Text(
                  'Instead of ${result.label}',
                  style: AppText.body(
                    size: 52,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'I could have put ${formatRupees(result.amountInr)} into '
                  'Bitcoin on ${_dateLabel(result.requestedDate)}.',
                  style: AppText.body(size: 52, height: 1.35),
                ),
                const SizedBox(height: 70),
                Text(
                  gained ? 'IT WOULD BE WORTH' : 'IT WOULD NOW BE',
                  style: AppText.mono(
                    size: 32,
                    weight: FontWeight.w700,
                    color: headline,
                    letterSpacing: 5,
                  ),
                ),
                const SizedBox(height: 16),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatRupees(result.valueNow),
                    style: AppText.mono(
                      size: 150,
                      weight: FontWeight.w700,
                      color: headline,
                      letterSpacing: -2,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '${result.multiple.toStringAsFixed(1)}x  ·  '
                  '${gained ? '+' : '-'}${formatRupees(result.gain.abs())}',
                  style: AppText.mono(
                    size: 48,
                    weight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(height: 1, color: AppColors.border),
                const SizedBox(height: 28),
                Text(
                  // Non-negotiable framing (DESIGN.md, TIME_MACHINE.md). It is
                  // in the image itself, because the image travels without the
                  // app around it.
                  'Illustrative only. Past prices, not a prediction. '
                  'Not investment advice.',
                  style: AppText.body(
                    size: 28,
                    color: AppColors.textFaint,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.accent, width: 2),
                      ),
                      child: Text(
                        'TEST YOUR OWN REGRET →',
                        style: AppText.mono(
                          size: 30,
                          weight: FontWeight.w700,
                          color: AppColors.accent,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _dateLabel(DateTime d) {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
