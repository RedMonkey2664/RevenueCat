import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../simulator/engine/candle_model.dart';
import 'model/chart_drawing.dart';
import 'model/chart_indicator.dart';
import 'model/chart_labels.dart';
import 'model/chart_layout.dart';
import 'model/chart_series.dart';
import 'model/chart_types.dart';
import 'model/chart_viewport.dart';
import 'painters/chart_base_painter.dart';
import 'painters/crosshair_painter.dart';

/// The shared interactive chart.
///
/// One widget serves the Simulator's replay, Live Markets and Custom
/// Simulation. It owns viewport and pointer state only; the *settings*
/// (chart type, interval, indicators) and the drawings are controlled by the
/// host, so a screen can persist them or hold them constant as it needs.
///
/// SPEC NOTE — DESIGN.md's original real/dummy map listed extra chart types,
/// timeframes, indicators and drawing tools as deliberately inert chrome.
/// Somi asked for them to be real. They are real here, and DESIGN.md has been
/// updated rather than left contradicting the app.
class ProChart extends StatefulWidget {
  const ProChart({
    required this.bars,
    required this.baseInterval,
    required this.settings,
    required this.labels,
    this.drawings = const <ChartDrawing>[],
    this.onDrawingsChanged,
    this.onIntervalUnavailable,
    this.replayCursorIndex,
    this.autoFollow = false,
    this.percentBaseline,
    this.onCrosshairChanged,
    this.showLastPriceLine = true,
    this.interactive = true,
    super.key,
  });

  /// The series at [baseInterval]. Coarser intervals are folded from this;
  /// finer ones need a refetch, which is [onIntervalUnavailable]'s job.
  final List<Candle> bars;
  final BarInterval baseInterval;

  final ChartSettings settings;
  final ChartLabels labels;

  final List<ChartDrawing> drawings;
  final ValueChanged<List<ChartDrawing>>? onDrawingsChanged;

  /// Called when the requested interval cannot be produced from [bars].
  /// A host with a live data source refetches; one with bundled data should
  /// not have offered the interval in the first place.
  final ValueChanged<BarInterval>? onIntervalUnavailable;

  /// Simulator only: index of the newest revealed bar.
  final int? replayCursorIndex;

  /// Keep the newest bar in view as the series grows. Used during replay.
  final bool autoFollow;

  /// Reference price for [PriceScale.percent]. Defaults to the first visible
  /// bar's close, which is what a standalone chart should do; the Simulator
  /// passes the level's opening close so blind mode's index stays stable as
  /// the player pans.
  final double? percentBaseline;

  /// Fires with the bar under the crosshair, or null when it lifts.
  final ValueChanged<Candle?>? onCrosshairChanged;

  final bool showLastPriceLine;

  /// False makes the chart a static picture — used by the Debrief's small
  /// review panes and by the Time Machine card.
  final bool interactive;

  @override
  State<ProChart> createState() => _ProChartState();
}

class _ProChartState extends State<ProChart> {
  ChartViewport? _viewport;
  Offset? _crosshair;
  int? _crosshairBar;
  ChartDrawing? _pending;
  String? _selectedDrawing;

  /// Bar count the viewport was last reconciled against, so a timeframe
  /// change re-frames the chart instead of leaving it pointing at an index
  /// that now means a different date.
  int _lastBarCount = -1;
  BarInterval? _lastInterval;

  // Gesture bookkeeping.
  double _scaleStartBars = 0;
  double _scaleStartFirst = 0;
  Offset? _drawStart;

  List<Candle> get _rawBars {
    final BarInterval target = widget.settings.interval;
    if (target == widget.baseInterval) return widget.bars;
    if (!widget.baseInterval.canAggregateTo(target)) return widget.bars;
    return ChartSeries.aggregate(
      widget.bars,
      from: widget.baseInterval,
      to: target,
    );
  }

  @override
  void didUpdateWidget(ProChart old) {
    super.didUpdateWidget(old);

    if (widget.settings.interval != old.settings.interval &&
        !widget.baseInterval.canAggregateTo(widget.settings.interval)) {
      // Tell the host on the next frame rather than during build.
      final BarInterval wanted = widget.settings.interval;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onIntervalUnavailable?.call(wanted);
      });
    }
  }

  void _reconcileViewport(int barCount) {
    final BarInterval interval = widget.settings.interval;

    if (_viewport == null ||
        _lastInterval != interval ||
        (_lastBarCount <= 0 && barCount > 0)) {
      _viewport = ChartViewport.initial(barCount);
      _lastInterval = interval;
      _lastBarCount = barCount;
      return;
    }

    if (barCount != _lastBarCount) {
      final bool wasAtRightEdge =
          _viewport!.lastIndex >= _lastBarCount - 1.5;
      if (widget.autoFollow && wasAtRightEdge) {
        // Follow the newest bar during replay, but only if the user has not
        // panned away to look at something. Yanking the view back under a
        // finger is the fastest way to make a chart feel broken.
        _viewport = _viewport!
            .copyWith(firstIndex: barCount - _viewport!.barsVisible)
            .clamped(barCount);
      } else {
        _viewport = _viewport!.clamped(barCount);
      }
      _lastBarCount = barCount;
    }
  }

  // ------------------------------------------------------------- gestures

  void _onScaleStart(ScaleStartDetails d, ChartGeometry g) {
    _scaleStartBars = _viewport!.barsVisible;
    _scaleStartFirst = _viewport!.firstIndex;

    if (widget.settings.tool.isDrawing) {
      _drawStart = d.localFocalPoint;
      _beginDrawing(d.localFocalPoint, g);
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d, ChartGeometry g, int barCount) {
    if (widget.settings.tool.isDrawing && _drawStart != null) {
      _extendDrawing(d.localFocalPoint, g);
      return;
    }

    setState(() {
      if ((d.scale - 1).abs() > 0.01) {
        final double focal =
            ((d.localFocalPoint.dx - g.plot.left) / g.plot.width)
                .clamp(0.0, 1.0);
        final double focalIndex = _scaleStartFirst + _scaleStartBars * focal;
        final double nextBars = (_scaleStartBars / d.scale).clamp(
          ChartViewport.minBarsVisible,
          ChartViewport.maxBarsVisible,
        );
        _viewport = _viewport!
            .copyWith(
              firstIndex: focalIndex - nextBars * focal,
              barsVisible: nextBars,
            )
            .clamped(barCount);
      } else {
        // focalPointDelta is the delta since the last event, so it applies to
        // the *current* viewport. Folding it into the gesture-start anchor
        // instead would make a pan-then-pinch gesture jump.
        _viewport = _viewport!
            .pannedBy(-d.focalPointDelta.dx / g.barWidth, barCount);
      }
    });
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_drawStart != null) {
      _commitDrawing();
      _drawStart = null;
    }
  }

  void _beginDrawing(Offset at, ChartGeometry g) {
    final List<Candle> bars = _rawBars;
    final double index = g.indexForX(at.dx);
    final DateTime t = DrawingAnchor.timeForIndex(bars, index);
    final double price = g.priceForY(at.dy);

    setState(() {
      _pending = ChartDrawing(
        id: 'd${DateTime.now().microsecondsSinceEpoch}',
        tool: widget.settings.tool,
        time1: t,
        price1: price,
      );
    });
  }

  void _extendDrawing(Offset at, ChartGeometry g) {
    final ChartDrawing? p = _pending;
    if (p == null || p.tool == ChartTool.horizontalLine) return;

    final List<Candle> bars = _rawBars;
    setState(() {
      _pending = p.withSecondPoint(
        DrawingAnchor.timeForIndex(bars, g.indexForX(at.dx)),
        g.priceForY(at.dy),
      );
    });
  }

  void _commitDrawing() {
    final ChartDrawing? p = _pending;
    if (p == null) return;

    // A trendline or rectangle needs two distinct points; a tap that never
    // moved is a mis-tap, not a zero-size drawing.
    final bool complete =
        p.tool == ChartTool.horizontalLine || p.isTwoPoint;

    setState(() {
      _pending = null;
      _selectedDrawing = complete ? p.id : null;
    });

    if (complete) {
      HapticFeedback.selectionClick();
      widget.onDrawingsChanged
          ?.call(<ChartDrawing>[...widget.drawings, p]);
    }
  }

  void _setCrosshair(Offset? at, ChartGeometry g) {
    if (at == null) {
      if (_crosshair == null) return;
      setState(() {
        _crosshair = null;
        _crosshairBar = null;
      });
      widget.onCrosshairChanged?.call(null);
      return;
    }

    final int? bar = g.barIndexAt(at.dx);
    if (bar == null) return;
    if (bar != _crosshairBar) HapticFeedback.selectionClick();

    setState(() {
      _crosshair = at;
      _crosshairBar = bar;
    });
    final List<Candle> bars = _rawBars;
    widget.onCrosshairChanged?.call(bar < bars.length ? bars[bar] : null);
  }

  void _resetView(int barCount) {
    setState(() {
      _viewport = ChartViewport.initial(barCount);
      _crosshair = null;
      _crosshairBar = null;
    });
  }

  /// Vertical drag on the price gutter zooms the price axis, which pins the
  /// range until autoscale is tapped — same as every desktop terminal.
  void _zoomPriceAxis(double dy, ChartGeometry g) {
    final double span = g.axisMax - g.axisMin;
    final double factor = 1 + dy / 220;
    final double mid = (g.axisMax + g.axisMin) / 2;
    final double next = (span * factor).clamp(span * 0.02, span * 50);

    setState(() {
      _viewport = _viewport!.copyWith(
        manualRange: (min: mid - next / 2, max: mid + next / 2),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Candle> bars = _rawBars;
    if (bars.isEmpty) {
      return Center(
        child: Text(
          'No data for this range.',
          style: AppText.body(size: 12, color: AppColors.textFaint),
        ),
      );
    }

    _reconcileViewport(bars.length);

    final List<Candle> drawBars =
        ChartSeries.forType(bars, widget.settings.chartType);
    final ComputedIndicators indicators =
        ComputedIndicators.compute(bars, widget.settings.indicators);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);
        final ChartLayout layout = ChartLayout.compute(
          size,
          indicatorPaneCount: indicators.panes.length,
        );

        final ChartViewport viewport = _viewport!;
        final ({int first, int last}) visible =
            viewport.visibleRange(bars.length);

        final PriceAxis axis = PriceAxis(
          scale: widget.settings.scale,
          basePrice: widget.percentBaseline ?? bars[visible.first].close,
        );

        final ({double min, double max}) range = viewport.manualRange ??
            ChartGeometry.autoRange(drawBars, viewport, axis) ??
            (min: 0, max: 1);

        final ChartGeometry priceGeometry = ChartGeometry(
          plot: layout.price,
          viewport: viewport,
          axis: axis,
          axisMin: range.min,
          axisMax: range.max,
          barCount: bars.length,
        );

        final List<ChartGeometry> paneGeometries = <ChartGeometry>[
          for (int i = 0; i < indicators.panes.length; i++)
            _paneGeometry(
              indicators.panes[i],
              layout.indicatorPanes[i],
              viewport,
              bars.length,
            ),
        ];

        final Widget chart = Stack(
          children: <Widget>[
            RepaintBoundary(
              child: CustomPaint(
                size: size,
                painter: ChartBasePainter(
                  rawBars: bars,
                  drawBars: drawBars,
                  chartType: widget.settings.chartType,
                  interval: widget.settings.interval,
                  layout: layout,
                  priceGeometry: priceGeometry,
                  paneGeometries: paneGeometries,
                  indicators: indicators,
                  labels: widget.labels,
                  drawings: widget.drawings,
                  pendingDrawing: _pending,
                  selectedDrawingId: _selectedDrawing,
                  replayCursorIndex: widget.replayCursorIndex,
                  showLastPriceLine: widget.showLastPriceLine,
                ),
              ),
            ),
            if (widget.interactive)
              CustomPaint(
                size: size,
                painter: CrosshairPainter(
                  bars: bars,
                  interval: widget.settings.interval,
                  layout: layout,
                  priceGeometry: priceGeometry,
                  paneGeometries: paneGeometries,
                  labels: widget.labels,
                  position: _crosshair,
                  barIndex: _crosshairBar,
                ),
              ),
          ],
        );

        if (!widget.interactive) return chart;

        return Stack(
          children: <Widget>[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: (ScaleStartDetails d) =>
                  _onScaleStart(d, priceGeometry),
              onScaleUpdate: (ScaleUpdateDetails d) =>
                  _onScaleUpdate(d, priceGeometry, bars.length),
              onScaleEnd: _onScaleEnd,
              onDoubleTap: () => _resetView(bars.length),
              onLongPressStart: (LongPressStartDetails d) =>
                  _setCrosshair(d.localPosition, priceGeometry),
              onLongPressMoveUpdate: (LongPressMoveUpdateDetails d) =>
                  _setCrosshair(d.localPosition, priceGeometry),
              onLongPressEnd: (LongPressEndDetails d) =>
                  _setCrosshair(null, priceGeometry),
              child: chart,
            ),
            // Price-gutter drag zone. Sits above the chart's own detector so
            // a vertical drag here scales the axis instead of panning.
            Positioned(
              right: 0,
              top: 0,
              width: layout.gutterWidth,
              height: layout.gutter.height,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (DragUpdateDetails d) =>
                    _zoomPriceAxis(d.delta.dy, priceGeometry),
                onDoubleTap: () => setState(
                  () => _viewport =
                      _viewport!.copyWith(clearManualRange: true),
                ),
              ),
            ),
            if (!viewport.isAutoscaled)
              Positioned(
                right: layout.gutterWidth + 6,
                bottom: layout.timeAxisHeight + 6,
                child: _AutoscaleChip(
                  onTap: () => setState(
                    () => _viewport =
                        _viewport!.copyWith(clearManualRange: true),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  ChartGeometry _paneGeometry(
    IndicatorPane pane,
    Rect rect,
    ChartViewport viewport,
    int barCount,
  ) {
    final ({double min, double max}) range =
        pane.fixedRange ?? _autoPaneRange(pane, viewport, barCount);

    return ChartGeometry(
      plot: rect,
      viewport: viewport,
      // Sub-panes are always linear: an RSI on a log axis is meaningless.
      axis: const PriceAxis(scale: PriceScale.linear, basePrice: 1),
      axisMin: range.min,
      axisMax: range.max,
      barCount: barCount,
    );
  }

  ({double min, double max}) _autoPaneRange(
    IndicatorPane pane,
    ChartViewport viewport,
    int barCount,
  ) {
    final ({int first, int last}) r = viewport.visibleRange(barCount);
    double min = double.infinity;
    double max = double.negativeInfinity;

    void consider(List<double?> values) {
      for (int i = r.first; i <= r.last && i < values.length; i++) {
        final double? v = values[i];
        if (v == null) continue;
        if (v < min) min = v;
        if (v > max) max = v;
      }
    }

    for (final IndicatorLine l in pane.lines) {
      consider(l.values);
    }
    final List<double?>? h = pane.histogram;
    if (h != null) consider(h);

    if (!min.isFinite || !max.isFinite) return (min: 0, max: 1);

    // Volume columns rise from zero, so the pane has to include it or the
    // bars are drawn hanging off the bottom edge.
    if (pane.spec.kind == IndicatorKind.volume) min = 0;
    if (pane.zeroLine) {
      final double m = math.max(min.abs(), max.abs());
      return (min: -m * 1.1, max: m * 1.1);
    }
    if (max - min < 1e-9) return (min: min - 1, max: max + 1);

    final double pad = (max - min) * 0.12;
    return (min: min - pad, max: max + pad);
  }
}

class _AutoscaleChip extends StatelessWidget {
  const _AutoscaleChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          border: Border.all(color: AppColors.borderStrong),
          borderRadius: AppRadius.chip,
        ),
        child: Text('AUTO', style: AppText.label(size: 9)),
      ),
    );
  }
}
