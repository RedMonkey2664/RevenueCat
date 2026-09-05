import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_nerve/data/sample/dev_sample_level.dart';
import 'package:market_nerve/features/simulator/engine/simulation_mode.dart';

import '../support/level_harness.dart';

/// The level screen must survive real phone sizes with every pane open.
///
/// A 60pt horizontal overflow in the transport bar shipped unnoticed because
/// the default test surface is 800x600 — wider than any phone — and Flutter
/// only reports each identical overflow once. These sizes are the actual
/// targets.
///
/// The indicators are switched on through stored preferences rather than by
/// tapping through the picker sheet: the thing under test is the *layout* with
/// two sub-panes stealing height from the chart, and driving a modal sheet on
/// six surface sizes would test the sheet instead.
void main() {
  const List<(String, Size)> sizes = <(String, Size)>[
    ('iPhone SE', Size(375, 667)),
    ('iPhone 14', Size(390, 844)),
    ('Pixel 7', Size(412, 915)),
  ];

  /// SMA over the price, plus RSI and MACD in panes of their own — the
  /// tallest arrangement the chart can be asked for.
  const String crowdedChart = '{"chart_type":"candles","interval":"1D",'
      '"scale":"linear","indicators":['
      '{"kind":"sma","period":20},'
      '{"kind":"rsi","period":14},'
      '{"kind":"macd","period":0}]}';

  for (final (String name, Size size) in sizes) {
    for (final SimulationMode mode in SimulationMode.values) {
      testWidgets('$name / ${mode.name} lays out with every pane open', (
        WidgetTester tester,
      ) async {
        await pumpLevelScreen(
          tester,
          DevSampleLevel.build(),
          mode: mode,
          surface: size,
          prefs: const <String, Object>{
            'flutter.chart_settings_v1': crowdedChart,
          },
        );

        expect(tester.takeException(), isNull, reason: 'idle on $name');

        await tester.tap(find.text('START RUN'));
        await tester.pump(const Duration(milliseconds: 4600));
        expect(tester.takeException(), isNull, reason: 'playing on $name');

        // Leave no timer running for the framework to complain about.
        //
        // Beginner mode may already have halted at a pause point by now, in
        // which case the transport bar shows play and there is no timer left
        // to stop — so the tap is conditional rather than assumed.
        final Finder pause = find.byIcon(Icons.pause);
        if (pause.evaluate().isNotEmpty) {
          await tester.tap(pause);
          await tester.pump();
        }
      });
    }
  }
}
