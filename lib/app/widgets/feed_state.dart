import 'package:flutter/material.dart';

import '../theme.dart';
import 'hud.dart';

/// One grammar for live data, four conditions, every screen (artboard 1l).
///
///   1. **Loading** — the value is hatched and pulses. Never a spinner alone,
///      and the row's label stays put: loading hatches the value only.
///   2. **Live / delayed** — the source is always named under the figure.
///   3. **Unavailable** — an honest dash and a red strip, with a retry.
///   4. **Empty** — a job, not an apology.
///
/// Plus the full-pane failure, for a chart or a Pivot that has nothing at all.
///
/// The rule the wireframe states, and that these widgets enforce by being the
/// only way to draw the states: *red strip = feed, red alarm = decision. They
/// never appear together.*

/// Where a live number came from, and how fresh it is.
///
/// Shown under every live figure — CLAUDE.md: "Every live number on screen
/// must be able to say where it came from."
class SourceTag extends StatelessWidget {
  const SourceTag({
    required this.source,
    required this.delayed,
    this.delayLabel,
    super.key,
  });

  /// Builds a tag from a provider's attribution string such as
  /// "Binance · live" or "Yahoo Finance · delayed".
  ///
  /// The delay is shown only when it can be measured from the quote's own
  /// timestamp — it is never assumed from what a feed usually does.
  factory SourceTag.fromAttribution(String attribution, {Duration? age}) {
    final bool delayed = attribution.toLowerCase().contains('delayed');
    final String name = attribution
        .split('·')
        .first
        .trim()
        .replaceAll(RegExp(r'\s*Finance$', caseSensitive: false), '')
        .toUpperCase();
    String? delay;
    if (delayed && age != null && age.inMinutes >= 1) {
      delay = '${age.inMinutes}M';
    }
    return SourceTag(source: name, delayed: delayed, delayLabel: delay);
  }

  /// e.g. "BINANCE", "YAHOO".
  final String source;
  final bool delayed;

  /// e.g. "15M". Omitted when the delay is unknown rather than guessed.
  final String? delayLabel;

  @override
  Widget build(BuildContext context) {
    final Color c = delayed ? AppColors.caution : AppColors.data;
    final String text = delayed
        ? '$source · DELAYED${delayLabel == null ? '' : ' $delayLabel'}'
        : '$source · LIVE';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (!delayed) ...<Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: AppText.label(size: 9.5, weight: FontWeight.w600, color: c),
        ),
      ],
    );
  }
}

/// State 1: a hatched value slot that pulses while it loads.
class FeedLoadingValue extends StatefulWidget {
  const FeedLoadingValue({this.width = 120, this.height = 18, super.key});

  final double width;
  final double height;

  @override
  State<FeedLoadingValue> createState() => _FeedLoadingValueState();
}

class _FeedLoadingValueState extends State<FeedLoadingValue>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.ambient,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool animate =
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (animate && !_c.isAnimating) _c.repeat(reverse: true);
    if (!animate && _c.isAnimating) _c.stop();

    return Semantics(
      label: 'Loading',
      child: FadeTransition(
        opacity: animate
            ? Tween<double>(begin: 0.45, end: 1).animate(_c)
            : const AlwaysStoppedAnimation<double>(0.8),
        child: HatchBox(
          width: widget.width,
          height: widget.height,
          color: AppColors.accent.withValues(alpha: 0.22),
        ),
      ),
    );
  }
}

/// State 3: a row whose feed failed. The label stays; the number becomes an
/// honest dash; a red strip on the left says *feed*, not *decision*.
class FeedUnavailableRow extends StatelessWidget {
  const FeedUnavailableRow({
    required this.title,
    this.onRetry,
    this.subtitle = 'FEED UNAVAILABLE',
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.down.withValues(alpha: 0.04),
        border: Border.all(color: AppColors.down.withValues(alpha: 0.35)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(width: 4, color: AppColors.down),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md + 2,
                  AppSpacing.sm + 4,
                  AppSpacing.md,
                  AppSpacing.sm + 4,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.railLabel(
                              size: 16,
                              weight: FontWeight.w600,
                              color: AppColors.textSecondary,
                              letterSpacing: 16 * 0.12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: AppText.label(
                              size: 10,
                              weight: FontWeight.w600,
                              color: AppColors.down.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          '—',
                          style: AppText.display(
                            size: 20,
                            color: AppColors.textFaint,
                          ),
                        ),
                        if (onRetry != null) RetryLink(onTap: onRetry!),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "RETRY ↻" as a real tap target.
class RetryLink extends StatelessWidget {
  const RetryLink({
    required this.onTap,
    this.color = AppColors.textFaint,
    super.key,
  });

  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Retry',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'RETRY',
                style: AppText.label(
                  size: 10,
                  weight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.refresh, size: 12, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// State 4: an empty list, framed as the next thing to do.
class FeedEmptyState extends StatelessWidget {
  const FeedEmptyState({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    this.icon = Icons.view_column_outlined,
    super.key,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return HudPanel(
      dashed: true,
      color: AppColors.accent.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 24, color: AppColors.accent.withValues(alpha: 0.7)),
          const SizedBox(height: AppSpacing.md + 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.railLabel(
              size: 19,
              weight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: 19 * 0.14,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppText.body(size: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          IntrinsicWidth(
            child: HudButton(
              label: actionLabel,
              onPressed: onAction,
              height: 50,
              fontSize: 15,
              letterSpacingEm: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// The full-pane failure — a chart, a custom sim or the Pivot with no data.
/// Hatched in red, says what failed and where, and offers the one fix.
class FeedFailurePane extends StatelessWidget {
  const FeedFailurePane({
    required this.message,
    this.title = 'NO DATA FOR THIS RANGE',
    this.onRetry,
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.down.withValues(alpha: 0.4)),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: HatchPainter(
                color: AppColors.down.withValues(alpha: 0.05),
                spacing: 14,
                strokeWidth: 6,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppText.label(
                      size: 12,
                      weight: FontWeight.w700,
                      color: AppColors.down,
                      letterSpacing: 12 * 0.22,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm + 2),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppText.body(
                      size: 13.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (onRetry != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.md + 2),
                    IntrinsicWidth(
                      child: HudButton(
                        label: 'RETRY ↻',
                        onPressed: onRetry,
                        color: AppColors.down,
                        height: 46,
                        fontSize: 14,
                        letterSpacingEm: 0.18,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
