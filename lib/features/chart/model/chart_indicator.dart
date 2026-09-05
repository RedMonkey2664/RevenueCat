import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import '../../../app/theme.dart';
import '../../../core/indicators/indicators.dart';
import '../../simulator/engine/candle_model.dart';
import 'chart_types.dart';

/// One plotted line of an indicator, aligned index-for-index with the bars.
@immutable
class IndicatorLine {
  const IndicatorLine({
    required this.values,
    required this.color,
    this.width = 1.3,
    this.dashed = false,
  });

  final List<double?> values;
  final Color color;
  final double width;
  final bool dashed;
}

/// A shaded region between two lines — Bollinger's envelope.
@immutable
class IndicatorBand {
  const IndicatorBand({
    required this.upper,
    required this.lower,
    required this.color,
  });

  final List<double?> upper;
  final List<double?> lower;
  final Color color;
}

/// A horizontal reference level inside a pane, e.g. RSI's 30 and 70.
@immutable
class IndicatorGuide {
  const IndicatorGuide(this.value, this.label);

  final double value;
  final String label;
}

/// An indicator that needs its own pane below the price chart, because its
/// units are not prices.
@immutable
class IndicatorPane {
  const IndicatorPane({
    required this.spec,
    required this.lines,
    this.histogram,
    this.histogramColors,
    this.fixedRange,
    this.guides = const <IndicatorGuide>[],
    this.zeroLine = false,
  });

  final IndicatorSpec spec;
  final List<IndicatorLine> lines;

  /// Bar series drawn as columns (volume, MACD histogram).
  final List<double?>? histogram;

  /// Per-bar colours for [histogram]. Same length when present.
  final List<Color>? histogramColors;

  /// Range to plot instead of autoscaling — RSI is always 0..100, and letting
  /// it autoscale would make an overbought reading look identical to a
  /// neutral one.
  final ({double min, double max})? fixedRange;

  final List<IndicatorGuide> guides;

  /// Draw a line at zero (MACD).
  final bool zeroLine;

  String get label => spec.label;
}

/// Everything the chart needs to paint the configured indicators.
@immutable
class ComputedIndicators {
  const ComputedIndicators({
    required this.overlayLines,
    required this.bands,
    required this.panes,
    required this.legend,
  });

  static const ComputedIndicators empty = ComputedIndicators(
    overlayLines: <IndicatorLine>[],
    bands: <IndicatorBand>[],
    panes: <IndicatorPane>[],
    legend: <String>[],
  );

  /// Lines drawn over the price pane, in price units.
  final List<IndicatorLine> overlayLines;

  final List<IndicatorBand> bands;

  /// Sub-panes, in the order they were added.
  final List<IndicatorPane> panes;

  /// Badge text for the chart legend, e.g. ["SMA 20", "EMA 50"].
  final List<String> legend;

  /// Computes every configured indicator over [bars].
  ///
  /// Always computed on raw prices; the painter converts the results through
  /// the same [PriceAxis] as the candles. For the linear and percent scales
  /// that is exactly equivalent to computing on rebased closes, because both
  /// transforms are affine and a moving average commutes with them. On the
  /// log scale it is deliberately *not* equivalent — an average of prices,
  /// drawn on a log axis, is the convention every charting package follows.
  static ComputedIndicators compute(
    List<Candle> bars,
    List<IndicatorSpec> specs,
  ) {
    if (bars.isEmpty || specs.isEmpty) return empty;

    final List<double> closes = <double>[
      for (final Candle c in bars) c.close,
    ];

    final List<IndicatorLine> overlays = <IndicatorLine>[];
    final List<IndicatorBand> bands = <IndicatorBand>[];
    final List<IndicatorPane> panes = <IndicatorPane>[];
    final List<String> legend = <String>[];

    // Distinct colours for repeated overlay kinds, so SMA 20 and SMA 50 are
    // visually separable without a settings dialog per line.
    int overlayColorCursor = 0;
    Color nextOverlayColor() =>
        _overlayPalette[overlayColorCursor++ % _overlayPalette.length];

    for (final IndicatorSpec spec in specs) {
      switch (spec.kind) {
        case IndicatorKind.sma:
          overlays.add(
            IndicatorLine(
              values: simpleMovingAverage(closes, spec.period),
              color: nextOverlayColor(),
            ),
          );
          legend.add(spec.label);

        case IndicatorKind.ema:
          overlays.add(
            IndicatorLine(
              values: exponentialMovingAverage(closes, spec.period),
              color: nextOverlayColor(),
            ),
          );
          legend.add(spec.label);

        case IndicatorKind.bollinger:
          final BollingerBands bb = bollingerBands(closes, spec.period);
          final Color c = nextOverlayColor();
          bands.add(
            IndicatorBand(
              upper: bb.upper,
              lower: bb.lower,
              color: c.withValues(alpha: 0.10),
            ),
          );
          overlays
            ..add(IndicatorLine(values: bb.upper, color: c, width: 1))
            ..add(
              IndicatorLine(
                values: bb.middle,
                color: c.withValues(alpha: 0.75),
                width: 1,
                dashed: true,
              ),
            )
            ..add(IndicatorLine(values: bb.lower, color: c, width: 1));
          legend.add(spec.label);

        case IndicatorKind.volume:
          if (bars.every((Candle c) => c.volume == null)) {
            // Several bundled campaign levels carry no volume — the equity
            // importer does not write it. Silently drawing an empty pane
            // would read as "no volume traded", so the pane is skipped and
            // the legend says why.
            legend.add('VOL · unavailable');
            break;
          }
          panes.add(
            IndicatorPane(
              spec: spec,
              lines: const <IndicatorLine>[],
              histogram: <double?>[for (final Candle c in bars) c.volume],
              histogramColors: <Color>[
                for (final Candle c in bars)
                  (c.isUp ? AppColors.up : AppColors.down)
                      .withValues(alpha: 0.55),
              ],
            ),
          );
          legend.add(spec.label);

        case IndicatorKind.rsi:
          panes.add(
            IndicatorPane(
              spec: spec,
              lines: <IndicatorLine>[
                IndicatorLine(
                  values: relativeStrengthIndex(closes, spec.period),
                  color: AppColors.accent,
                ),
              ],
              fixedRange: (min: 0, max: 100),
              guides: const <IndicatorGuide>[
                IndicatorGuide(70, '70'),
                IndicatorGuide(30, '30'),
              ],
            ),
          );
          legend.add(spec.label);

        case IndicatorKind.macd:
          final MacdResult m = macd(closes);
          panes.add(
            IndicatorPane(
              spec: spec,
              lines: <IndicatorLine>[
                IndicatorLine(values: m.macd, color: AppColors.accent),
                IndicatorLine(
                  values: m.signal,
                  color: AppColors.simulatedBadge,
                ),
              ],
              histogram: m.histogram,
              histogramColors: <Color>[
                for (final double? h in m.histogram)
                  ((h ?? 0) >= 0 ? AppColors.up : AppColors.down)
                      .withValues(alpha: 0.45),
              ],
              zeroLine: true,
            ),
          );
          legend.add(spec.label);
      }
    }

    return ComputedIndicators(
      overlayLines: overlays,
      bands: bands,
      panes: panes,
      legend: legend,
    );
  }

  static const List<Color> _overlayPalette = <Color>[
    AppColors.simulatedBadge,
    Color(0xFF8B8CF7),
    Color(0xFF4ADE80),
    Color(0xFFF472B6),
  ];
}
