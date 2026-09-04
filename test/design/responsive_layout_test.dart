import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_nerve/data/sample/dev_sample_level.dart';
import 'package:market_nerve/features/simulator/engine/simulation_mode.dart';
import 'package:market_nerve/features/simulator/level/level_screen.dart';

/// The level screen must survive real phone sizes with every indicator on.
///
/// A 60pt horizontal overflow in the transport bar shipped unnoticed because
/// the default test surface is 800x600 — wider than any phone — and Flutter
/// only reports each identical overflow once. These sizes are the actual
/// targets.
void main() {
  const List<(String, Size)> sizes = <(String, Size)>[
    ('iPhone SE', Size(375, 667)),
    ('iPhone 14', Size(390, 844)),
    ('Pixel 7', Size(412, 915)),
  ];

  for (final (String name, Size size) in sizes) {
    for (final SimulationMode mode in SimulationMode.values) {
      testWidgets('$name / ${mode.name} lays out with both indicators on', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: LevelScreen(level: DevSampleLevel.build(), mode: mode),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'idle on $name');

        // The console toolbar scrolls horizontally; on a narrow phone the
        // RSI chip starts off-screen, and a tap that misses would make this
        // test silently prove nothing.
        await tester.ensureVisible(find.text('RSI 14'));
        await tester.pump();
        await tester.tap(find.text('RSI 14'));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'RSI on, $name');

        await tester.tap(find.text('START RUN'));
        await tester.pump(const Duration(milliseconds: 4600));
        expect(tester.takeException(), isNull, reason: 'playing on $name');
      });
    }
  }
}
