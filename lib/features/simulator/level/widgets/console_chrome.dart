import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../app/widgets/locked_feature_chip.dart';

/// The trading-console chrome above the chart.
///
/// Real and dummy sit side by side deliberately (DESIGN.md): the screen should
/// *look* like a full terminal, while only the controls that are load-bearing
/// for the decision loop actually work. Everything inert is visibly locked.
///
/// Real here: the 1D timeframe, the candlestick type, the SMA and RSI toggles.
/// Dummy here: every other timeframe, chart type, indicator, the drawing
/// tools and the watchlist switcher.
class ConsoleChrome extends StatelessWidget {
  const ConsoleChrome({
    required this.smaEnabled,
    required this.rsiEnabled,
    required this.onToggleSma,
    required this.onToggleRsi,
    super.key,
  });

  final bool smaEnabled;
  final bool rsiEnabled;
  final VoidCallback onToggleSma;
  final VoidCallback onToggleRsi;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      // Fade the right edge so the strip reads as "scrolls further" rather
      // than "cut off". A hard clip at the screen edge looked like a bug.
      child: ShaderMask(
        shaderCallback: (Rect rect) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: <double>[0, 0.86, 1],
          colors: <Color>[Colors.white, Colors.white, Colors.transparent],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: SizedBox(
        // Tall enough to hold 44pt tap targets. Shorter looked tidier but
        // clipped the chips' own hit boxes.
        height: kMinTouchTarget + 6,
        // One scrolling toolbar rather than three stacked strips. Three rows
        // cost ~90px of vertical budget on a screen whose whole point is the
        // chart, and on a short device that pushed the layout past the bottom
        // of the screen. It also reads more like a real terminal toolbar.
        // A non-lazy Row inside a scroll view, not a ListView: every control
        // must actually exist in the tree. DESIGN.md's rule is that dummy
        // chrome is *visibly present*, and a lazily-built list quietly drops
        // the ones that are scrolled off.
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: <Widget>[
              const _Group(label: 'TF'),
              const _ActiveChip(label: '1D'),
              for (final String tf in <String>['1m', '5m', '1H', '1W', '1M'])
                LockedFeatureChip(label: tf, compact: true),
              const _Divider(),
              const _Group(label: 'IND'),
              _ToggleChip(label: 'SMA 20', active: smaEnabled, onTap: onToggleSma),
              _ToggleChip(label: 'RSI 14', active: rsiEnabled, onTap: onToggleRsi),
              const LockedFeatureChip(label: 'MACD', compact: true),
              const LockedFeatureChip(label: 'BOLL', compact: true),
              const LockedFeatureChip(label: 'VOL PROFILE', compact: true),
              const _Divider(),
              const _Group(label: 'TYPE'),
              const _ActiveChip(label: 'CANDLE'),
              const LockedFeatureChip(label: 'LINE', compact: true),
              const LockedFeatureChip(label: 'HEIKIN-ASHI', compact: true),
              const LockedFeatureChip(label: 'BAR', compact: true),
              const _Divider(),
              const _Group(label: 'TOOLS'),
              const LockedFeatureChip(
                label: 'TRENDLINE',
                icon: Icons.show_chart,
                compact: true,
              ),
              const LockedFeatureChip(
                label: 'RECT',
                icon: Icons.crop_square,
                compact: true,
              ),
              const LockedFeatureChip(
                label: 'NOTE',
                icon: Icons.edit_outlined,
                compact: true,
              ),
              const LockedFeatureChip(
                label: 'WATCHLIST',
                icon: Icons.list_alt,
                compact: true,
              ),
            ]
                .map(
                  (Widget w) => Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: Center(child: w),
                  ),
                )
                .toList(),
          ),
        ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: AppText.label());
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 16,
        color: AppColors.border,
      );
}

/// A control that is real and permanently on (the 1D timeframe, candlesticks).
class _ActiveChip extends StatelessWidget {
  const _ActiveChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.accent),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: AppText.mono(
          size: 10,
          weight: FontWeight.w700,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

/// A real, switchable indicator.
class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: active ? AppColors.accent : AppColors.textSecondary,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: AppText.mono(
            size: 10,
            weight: FontWeight.w700,
            color: active ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
