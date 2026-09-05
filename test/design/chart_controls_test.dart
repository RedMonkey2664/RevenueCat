import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_nerve/data/sample/dev_sample_level.dart';
import 'package:market_nerve/features/chart/model/chart_types.dart';
import 'package:market_nerve/features/chart/pro_chart.dart';
import 'package:market_nerve/features/chart/widgets/chart_toolbar.dart';

import '../support/level_harness.dart';

/// Replaces the old `dummy_chrome_test.dart`.
///
/// DESIGN.md used to require that the chart's extra timeframes, chart types,
/// indicators and drawing tools be visibly present but inert, and that test
/// enforced the inertness mechanically. Somi asked for them to be real, so the
/// rule is inverted and enforced the same way: a control on this toolbar has
/// to *do something*, and a control the screen cannot honour must be absent
/// rather than present-and-dead.
void main() {
  /// The toolbar only exists once the run is under way — before that the
  /// pre-run brief covers the chart. So every test here starts playback and
  /// immediately pauses it, which is also the state a player spends most of
  /// their time in.
  Future<void> pumpLevel(WidgetTester tester) async {
    await pumpLevelScreen(
      tester,
      DevSampleLevel.build(),
      surface: const Size(412, 915),
    );
    await tester.tap(find.text('START RUN'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
  }

  testWidgets('the toolbar is on screen and nothing on it is locked', (
    WidgetTester tester,
  ) async {
    await pumpLevel(tester);

    expect(find.byType(ChartToolbar), findsOneWidget);
    expect(find.byType(ProChart), findsOneWidget);

    // The old locked-chip vocabulary must be gone, not merely hidden.
    final String text = visibleText(tester);
    for (final String gone in <String>['LOCKED', 'NOT BUILT YET', 'PRO']) {
      expect(
        text.contains(gone),
        isFalse,
        reason: '"$gone" belonged to the dummy-chrome layer that was removed',
      );
    }
  });

  testWidgets('only timeframes the level can actually serve are offered', (
    WidgetTester tester,
  ) async {
    await pumpLevel(tester);

    // A level's bundled bars are daily, so daily and coarser are foldable.
    for (final String offered in <String>['1D', '1W', '1M']) {
      expect(find.text(offered), findsOneWidget, reason: '$offered is real');
    }
    // Intraday would need data the level does not carry, so it is absent
    // rather than present and inert.
    for (final String absent in <String>['1m', '5m', '15m', '1H', '4H']) {
      expect(
        find.text(absent),
        findsNothing,
        reason: '$absent cannot be served from daily bars',
      );
    }
  });

  testWidgets('the chart type picker opens and actually switches type', (
    WidgetTester tester,
  ) async {
    await pumpLevel(tester);

    expect(
      tester.widget<ProChart>(find.byType(ProChart)).settings.chartType,
      ChartType.candles,
    );

    await tester.tap(find.byIcon(Icons.candlestick_chart));
    await tester.pumpAndSettle();

    expect(find.text('CHART TYPE'), findsOneWidget);
    for (final ChartType t in ChartType.values) {
      expect(find.text(t.label), findsOneWidget);
    }

    await tester.tap(find.text('Heikin-Ashi'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<ProChart>(find.byType(ProChart)).settings.chartType,
      ChartType.heikinAshi,
      reason: 'picking a type must change the chart, not just the sheet',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the indicator sheet adds a real indicator', (
    WidgetTester tester,
  ) async {
    await pumpLevel(tester);

    expect(
      tester.widget<ProChart>(find.byType(ProChart)).settings.indicators,
      isEmpty,
    );

    await tester.tap(find.byIcon(Icons.functions));
    await tester.pumpAndSettle();

    expect(find.text('INDICATORS'), findsOneWidget);
    // Every indicator DESIGN.md used to list as dummy is now offered.
    for (final IndicatorKind k in IndicatorKind.values) {
      expect(find.text(k.description), findsOneWidget);
    }

    await tester.tap(find.text('Relative Strength Index'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final List<IndicatorSpec> applied =
        tester.widget<ProChart>(find.byType(ProChart)).settings.indicators;
    expect(applied, hasLength(1));
    expect(applied.single.kind, IndicatorKind.rsi);
    expect(applied.single.period, 14);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every drawing tool arms without crashing', (
    WidgetTester tester,
  ) async {
    await pumpLevel(tester);

    for (final (IconData icon, ChartTool expected) in <(IconData, ChartTool)>[
      (Icons.timeline, ChartTool.trendline),
      (Icons.horizontal_rule, ChartTool.horizontalLine),
      (Icons.crop_square, ChartTool.rectangle),
      (Icons.near_me_outlined, ChartTool.cursor),
    ]) {
      await tester.tap(find.byIcon(icon));
      await tester.pump();
      expect(
        tester.widget<ProChart>(find.byType(ProChart)).settings.tool,
        expected,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('blind mode pins the price scale and hides the toggle', (
    WidgetTester tester,
  ) async {
    await pumpLevel(tester);

    // Blind mode rebases to an index of 100, so a Linear/Log toggle would only
    // move the gridlines onto odd index values.
    for (final PriceScale s in PriceScale.values) {
      expect(find.text(s.label), findsNothing);
    }
    expect(
      tester.widget<ProChart>(find.byType(ProChart)).settings.scale,
      PriceScale.percent,
    );
  });
}
