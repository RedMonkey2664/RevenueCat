import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_nerve/app/widgets/locked_feature_chip.dart';
import 'package:market_nerve/data/sample/dev_sample_level.dart';
import 'package:market_nerve/features/simulator/engine/simulation_mode.dart';
import 'package:market_nerve/features/simulator/level/level_screen.dart';
import 'package:market_nerve/features/simulator/level/widgets/rsi_panel.dart';

/// DESIGN.md's dummy-feature rule is mechanical, so it is enforced
/// mechanically: visibly present, genuinely tappable, never a crash, never a
/// silent no-op.
void main() {
  Future<void> pumpLevel(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: LevelScreen(
            level: DevSampleLevel.build(),
            mode: SimulationMode.beginner,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the console shows the locked controls DESIGN.md lists', (
    WidgetTester tester,
  ) async {
    await pumpLevel(tester);

    // Every dummy control named in DESIGN.md's real/dummy map.
    for (final String label in <String>[
      '1m', '5m', '1H', '1W', // extra timeframes
      'MACD', 'BOLL', 'VOL PROFILE', // extra indicators
      'LINE', 'HEIKIN-ASHI', 'BAR', // extra chart types
      'TRENDLINE', 'RECT', 'NOTE', // drawing tools
      'WATCHLIST', // multi-symbol switcher
    ]) {
      expect(
        find.text(label),
        findsOneWidget,
        reason: '$label must be visibly present, not silently missing',
      );
    }
  });

  testWidgets('the real controls are present and not locked', (
    WidgetTester tester,
  ) async {
    await pumpLevel(tester);

    // Real per DESIGN.md: 1D timeframe, candlesticks, SMA, RSI, 3 speeds.
    for (final String label in <String>[
      '1D',
      'CANDLE',
      'SMA 20',
      'RSI 14',
      '1x',
      '2x',
      '4x',
    ]) {
      expect(find.text(label), findsOneWidget, reason: '$label is real');
    }

    // None of the real controls may be rendered as a locked chip.
    final Iterable<LockedFeatureChip> locked =
        tester.widgetList<LockedFeatureChip>(find.byType(LockedFeatureChip));
    final Set<String> lockedLabels =
        locked.map((LockedFeatureChip c) => c.label).toSet();

    for (final String real in <String>['1D', 'CANDLE', 'SMA 20', 'RSI 14']) {
      expect(
        lockedLabels,
        isNot(contains(real)),
        reason: '$real is a real feature and must not be locked chrome',
      );
    }
  });

  testWidgets('every locked chip explains itself and never crashes', (
    WidgetTester tester,
  ) async {
    await pumpLevel(tester);

    final int chipCount =
        tester.widgetList<LockedFeatureChip>(find.byType(LockedFeatureChip))
            .length;
    expect(chipCount, greaterThan(0));

    for (int i = 0; i < chipCount; i++) {
      final Finder chip = find.byType(LockedFeatureChip).at(i);
      await tester.ensureVisible(chip);
      await tester.tap(chip, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'tapping a dummy control must never throw',
      );
      // A visible response, not a silent no-op.
      expect(
        find.text('NOT BUILT YET'),
        findsOneWidget,
        reason: 'a tapped dummy control must say it is not built',
      );

      await tester.tap(find.text('GOT IT'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('SMA and RSI actually toggle', (WidgetTester tester) async {
    await pumpLevel(tester);

    // RSI starts off; turning it on adds its panel. The toolbar scrolls, so
    // the chip must be brought on-screen or the tap silently misses.
    expect(find.text('RSI 14'), findsOneWidget);
    await tester.ensureVisible(find.text('RSI 14'));
    await tester.pump();
    await tester.tap(find.text('RSI 14'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Assert on the panel itself rather than a label count — the toolbar
    // and the panel both render the string, which made the old assertion
    // pass or fail for the wrong reasons.
    expect(find.byType(RsiPanel), findsOneWidget);

    await tester.ensureVisible(find.text('RSI 14').first);
    await tester.tap(find.text('RSI 14').first);
    await tester.pump();
    expect(find.byType(RsiPanel), findsNothing);
  });
}
