import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart';

/// Where each pane sits inside the chart's box.
///
/// Computed once per paint and shared by the base painter, the crosshair
/// painter and the hit-testing in the gesture layer, so the three cannot
/// disagree about which pixel belongs to which pane.
@immutable
class ChartLayout {
  const ChartLayout({
    required this.price,
    required this.indicatorPanes,
    required this.gutterWidth,
    required this.timeAxisHeight,
    required this.size,
  });

  /// Plot rect of the main price pane, excluding the gutter.
  final Rect price;

  /// Plot rects of the sub-panes, top to bottom.
  final List<Rect> indicatorPanes;

  final double gutterWidth;
  final double timeAxisHeight;
  final Size size;

  static const double defaultGutterWidth = 58;
  static const double defaultTimeAxisHeight = 20;
  static const double paneGap = 6;

  /// A sub-pane is never allowed to squeeze the price pane below this.
  static const double minPriceHeight = 90;

  factory ChartLayout.compute(
    Size size, {
    required int indicatorPaneCount,
    double gutterWidth = defaultGutterWidth,
    double timeAxisHeight = defaultTimeAxisHeight,
  }) {
    final double plotWidth = math.max(1, size.width - gutterWidth);
    final double contentHeight = math.max(1, size.height - timeAxisHeight);

    if (indicatorPaneCount <= 0) {
      return ChartLayout(
        price: Rect.fromLTWH(0, 0, plotWidth, contentHeight),
        indicatorPanes: const <Rect>[],
        gutterWidth: gutterWidth,
        timeAxisHeight: timeAxisHeight,
        size: size,
      );
    }

    // Each sub-pane wants ~22% of the box, capped so three of them do not
    // bury the candles, and floored so a very short chart still shows
    // something rather than a 4px sliver.
    final double wanted = (contentHeight * 0.22).clamp(44.0, 96.0);
    final double budget =
        math.max(0, contentHeight - minPriceHeight - paneGap * indicatorPaneCount);
    final double paneHeight =
        math.min(wanted, budget / indicatorPaneCount);

    final List<Rect> panes = <Rect>[];
    double bottom = contentHeight;
    for (int i = 0; i < indicatorPaneCount; i++) {
      final double top = bottom - paneHeight;
      panes.insert(0, Rect.fromLTRB(0, top, plotWidth, bottom));
      bottom = top - paneGap;
    }

    return ChartLayout(
      price: Rect.fromLTRB(0, 0, plotWidth, math.max(1, bottom)),
      indicatorPanes: panes,
      gutterWidth: gutterWidth,
      timeAxisHeight: timeAxisHeight,
      size: size,
    );
  }

  /// Every plot rect, price pane first.
  List<Rect> get allPanes => <Rect>[price, ...indicatorPanes];

  double get plotWidth => price.width;

  Rect get gutter =>
      Rect.fromLTWH(price.right, 0, gutterWidth, size.height - timeAxisHeight);

  Rect get timeAxis => Rect.fromLTWH(
        0,
        size.height - timeAxisHeight,
        price.width,
        timeAxisHeight,
      );

  /// The pane containing [dy], or null when the point is on the time axis.
  /// Index 0 is the price pane.
  int? paneIndexAt(double dy) {
    final List<Rect> panes = allPanes;
    for (int i = 0; i < panes.length; i++) {
      if (dy >= panes[i].top && dy <= panes[i].bottom) return i;
    }
    return null;
  }
}
