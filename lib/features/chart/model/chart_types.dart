import 'package:flutter/foundation.dart';

import '../../../core/market/bar_interval.dart';

export '../../../core/market/bar_interval.dart' show BarInterval;

/// How the price series is drawn.
///
/// All four are real (unlike DESIGN.md's original dummy-chrome map, which
/// listed line and Heikin-Ashi as inert). Somi asked for a working
/// TradingView-style chart; DESIGN.md is updated to match rather than left
/// contradicting the app.
enum ChartType {
  candles('Candles'),
  heikinAshi('Heikin-Ashi'),
  line('Line'),
  area('Area');

  const ChartType(this.label);

  final String label;

  /// Line and area draw a single close path, so they skip the body/wick pass.
  bool get isPathStyle => this == ChartType.line || this == ChartType.area;

  static ChartType fromName(String name) => ChartType.values.firstWhere(
        (ChartType t) => t.name == name,
        orElse: () => ChartType.candles,
      );
}

/// The active pointer tool.
///
/// [ChartTool.cursor] is the default: drag pans, pinch zooms, long-press
/// raises the crosshair. Any other tool takes over drag to create a drawing,
/// which is why panning has to be explicitly disabled while one is armed.
enum ChartTool {
  cursor('Cursor', 'Pan, pinch to zoom, hold for crosshair'),
  trendline('Trendline', 'Drag from one point to another'),
  horizontalLine('Price line', 'Tap a price level'),
  rectangle('Rectangle', 'Drag to box a region');

  const ChartTool(this.label, this.hint);

  final String label;
  final String hint;

  bool get isDrawing => this != ChartTool.cursor;
}

/// A price scale mode.
enum PriceScale {
  /// Linear price axis.
  linear('Linear'),

  /// Percent change from the first visible bar's close. Also what blind mode
  /// forces, since an absolute axis leaks the asset.
  percent('Percent'),

  /// Log price axis — the honest way to compare a multi-year series where the
  /// price changed by an order of magnitude.
  logarithmic('Log');

  const PriceScale(this.label);

  final String label;
}

/// Immutable snapshot of everything the toolbar controls.
@immutable
class ChartSettings {
  const ChartSettings({
    this.chartType = ChartType.candles,
    this.interval = BarInterval.d1,
    this.scale = PriceScale.linear,
    this.tool = ChartTool.cursor,
    this.indicators = const <IndicatorSpec>[],
  });

  final ChartType chartType;
  final BarInterval interval;
  final PriceScale scale;
  final ChartTool tool;
  final List<IndicatorSpec> indicators;

  ChartSettings copyWith({
    ChartType? chartType,
    BarInterval? interval,
    PriceScale? scale,
    ChartTool? tool,
    List<IndicatorSpec>? indicators,
  }) {
    return ChartSettings(
      chartType: chartType ?? this.chartType,
      interval: interval ?? this.interval,
      scale: scale ?? this.scale,
      tool: tool ?? this.tool,
      indicators: indicators ?? this.indicators,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'chart_type': chartType.name,
        'interval': interval.label,
        'scale': scale.name,
        'indicators': <Map<String, dynamic>>[
          for (final IndicatorSpec s in indicators) s.toJson(),
        ],
      };

  factory ChartSettings.fromJson(Map<String, dynamic> json) {
    return ChartSettings(
      chartType: ChartType.fromName(json['chart_type'] as String? ?? ''),
      interval: BarInterval.fromLabel(json['interval'] as String? ?? '1D'),
      scale: PriceScale.values.firstWhere(
        (PriceScale s) => s.name == json['scale'],
        orElse: () => PriceScale.linear,
      ),
      indicators: <IndicatorSpec>[
        for (final dynamic s in (json['indicators'] as List<dynamic>?) ??
            const <dynamic>[])
          IndicatorSpec.fromJson(s as Map<String, dynamic>),
      ],
    );
  }
}

/// Which indicator, at what period.
enum IndicatorKind {
  sma('SMA', 'Simple moving average', overlay: true, defaultPeriod: 20),
  ema('EMA', 'Exponential moving average', overlay: true, defaultPeriod: 20),
  bollinger('BB', 'Bollinger Bands', overlay: true, defaultPeriod: 20),
  volume('VOL', 'Volume', overlay: false, defaultPeriod: 0),
  rsi('RSI', 'Relative Strength Index', overlay: false, defaultPeriod: 14),
  macd('MACD', 'MACD (12, 26, 9)', overlay: false, defaultPeriod: 0);

  const IndicatorKind(
    this.code,
    this.description, {
    required this.overlay,
    required this.defaultPeriod,
  });

  /// Short badge text drawn in the chart legend.
  final String code;

  final String description;

  /// True when it draws over the price pane; false when it needs its own pane
  /// below (because its units are not prices).
  final bool overlay;

  /// 0 for indicators with no single period knob.
  final int defaultPeriod;

  bool get hasPeriod => defaultPeriod > 0;

  static IndicatorKind fromName(String name) =>
      IndicatorKind.values.firstWhere(
        (IndicatorKind k) => k.name == name,
        orElse: () => IndicatorKind.sma,
      );
}

/// One configured indicator on the chart.
@immutable
class IndicatorSpec {
  const IndicatorSpec({required this.kind, required this.period});

  IndicatorSpec.defaultFor(this.kind) : period = kind.defaultPeriod;

  final IndicatorKind kind;

  /// Ignored by kinds where [IndicatorKind.hasPeriod] is false.
  final int period;

  String get label =>
      kind.hasPeriod ? '${kind.code} $period' : kind.code;

  /// Identity for add/remove: two SMAs at different periods coexist, two at
  /// the same period do not.
  String get id => '${kind.name}_$period';

  IndicatorSpec withPeriod(int p) => IndicatorSpec(kind: kind, period: p);

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'kind': kind.name, 'period': period};

  factory IndicatorSpec.fromJson(Map<String, dynamic> json) {
    final IndicatorKind kind =
        IndicatorKind.fromName(json['kind'] as String? ?? '');
    return IndicatorSpec(
      kind: kind,
      period: (json['period'] as num?)?.toInt() ?? kind.defaultPeriod,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is IndicatorSpec && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
