import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../model/chart_types.dart';

/// Add, configure and remove indicators.
///
/// Returns the full replacement list on Done, so the host applies one change
/// rather than reconciling a stream of add/remove events.
class IndicatorSheet extends StatefulWidget {
  const IndicatorSheet({required this.selected, super.key});

  final List<IndicatorSpec> selected;

  @override
  State<IndicatorSheet> createState() => _IndicatorSheetState();
}

class _IndicatorSheetState extends State<IndicatorSheet> {
  late final List<IndicatorSpec> _specs =
      List<IndicatorSpec>.of(widget.selected);

  /// Periods offered per kind. A free-text field would let someone ask for
  /// SMA(2000) on a 126-bar window and get an empty line with no explanation.
  static const List<int> _periods = <int>[7, 9, 14, 20, 50, 100, 200];

  void _toggle(IndicatorKind kind) {
    setState(() {
      final int at = _specs.indexWhere((IndicatorSpec s) => s.kind == kind);
      if (at >= 0) {
        _specs.removeAt(at);
      } else {
        _specs.add(IndicatorSpec.defaultFor(kind));
      }
    });
  }

  void _setPeriod(IndicatorSpec spec, int period) {
    setState(() {
      final int at = _specs.indexOf(spec);
      if (at >= 0) _specs[at] = spec.withPeriod(period);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                const SizedBox(width: AppSpacing.md),
                Text('INDICATORS', style: AppText.label()),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(_specs),
                  child: Text(
                    'Done',
                    style: AppText.body(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final IndicatorKind kind in IndicatorKind.values)
                    _row(kind),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IndicatorKind kind) {
    final int at = _specs.indexWhere((IndicatorSpec s) => s.kind == kind);
    final bool on = at >= 0;
    final IndicatorSpec? spec = on ? _specs[at] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ListTile(
          onTap: () => _toggle(kind),
          leading: Container(
            width: 40,
            alignment: Alignment.center,
            child: Text(
              kind.code,
              style: AppText.mono(
                size: 11,
                weight: FontWeight.w700,
                color: on ? AppColors.accent : AppColors.textFaint,
              ),
            ),
          ),
          title: Text(kind.description, style: AppText.body(size: 13)),
          subtitle: Text(
            kind.overlay ? 'Drawn over the price' : 'Own pane',
            style: AppText.body(size: 11, color: AppColors.textFaint),
          ),
          trailing: Switch.adaptive(
            value: on,
            activeThumbColor: AppColors.accent,
            onChanged: (_) => _toggle(kind),
          ),
        ),
        if (on && spec != null && kind.hasPeriod)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.sm,
            ),
            child: Wrap(
              spacing: AppSpacing.xs,
              children: <Widget>[
                for (final int p in _periods)
                  GestureDetector(
                    onTap: () => _setPeriod(spec, p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: spec.period == p
                            ? AppColors.accent.withValues(alpha: 0.14)
                            : Colors.transparent,
                        border: Border.all(
                          color: spec.period == p
                              ? AppColors.accent
                              : AppColors.border,
                        ),
                        borderRadius: AppRadius.chip,
                      ),
                      child: Text(
                        '$p',
                        style: AppText.mono(
                          size: 11,
                          color: spec.period == p
                              ? AppColors.accent
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}
