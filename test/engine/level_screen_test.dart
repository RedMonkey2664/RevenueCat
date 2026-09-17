import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histox/app/widgets/hud.dart';
import 'package:histox/data/sample/dev_sample_level.dart';
import 'package:histox/features/simulator/engine/simulation_mode.dart';

import '../support/level_harness.dart' as harness;

/// Mounts the real screen through the real widget tree.
///
/// The engine unit tests override `currentLevelProvider` on a root
/// ProviderContainer, which is not how the app wires it — the screen supplies
/// the level through a *nested* ProviderScope. That difference hid a crash on
/// open: Riverpod only re-scopes a provider into a child scope when it
/// declares `dependencies`. These tests exist to keep that path covered.
void main() {
  Future<void> pumpLevelScreen(
    WidgetTester tester, {
    SimulationMode mode = SimulationMode.beginner,
  }) =>
      harness.pumpLevelScreen(tester, DevSampleLevel.build(), mode: mode);

  testWidgets('opens without throwing and starts blind', (
    WidgetTester tester,
  ) async {
    await pumpLevelScreen(tester);

    expect(tester.takeException(), isNull);

    // Blind mode: the redaction plate is on screen, the real asset name is
    // not.
    expect(find.byType(RedactionPlate), findsOneWidget);
    expect(find.text(DevSampleLevel.assetLabel), findsNothing);
    expect(find.text('DAY 1 / 130'), findsOneWidget);

    // The non-negotiable framing is present during play.
    expect(
      find.textContaining('SIMULATED'),
      findsOneWidget,
      reason: 'the virtual-capital badge must be visible during a run',
    );
    // The dev sample must announce that its numbers are generated.
    expect(find.textContaining('SYNTHETIC DATA'), findsOneWidget);
  });

  testWidgets('START RUN begins playback', (WidgetTester tester) async {
    await pumpLevelScreen(tester);

    expect(find.text('START RUN'), findsOneWidget);
    expect(find.text('NO DECISION PENDING'), findsNothing);

    await tester.tap(find.text('START RUN'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('NO DECISION PENDING'), findsOneWidget);
    expect(find.text('START RUN'), findsNothing);

    // Let the replay timer advance past a few candles.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('DAY 1 / 130'), findsNothing);

    // Leave no pending timer behind for the test framework to complain about.
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
  });

  testWidgets('REVEAL & SCORE opens the Debrief in beginner mode', (
    WidgetTester tester,
  ) async {
    await pumpLevelScreen(tester);

    // Drive the whole run: answer every scripted moment, then let playback
    // reach the end.
    await tester.tap(find.text('START RUN'));
    await tester.pump();

    for (int i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final Finder hold = find.text('HOLD');
      if (hold.evaluate().isNotEmpty) {
        await tester.tap(hold);
        await tester.pump();
      }
      if (find.text('REVEAL & SCORE').evaluate().isNotEmpty) break;
    }

    expect(
      find.text('REVEAL & SCORE'),
      findsOneWidget,
      reason: 'the run must reach completion',
    );

    await tester.tap(find.text('REVEAL & SCORE'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('DEBRIEF'), findsOneWidget);
    expect(find.text('DISCIPLINE SCORE'), findsOneWidget);

    // Blind mode is over: the reveal names the real asset. It starts closed
    // (artboard 1e), so open it first.
    await tester.tap(find.text('THE REVEAL'));
    await tester.pumpAndSettle();
    expect(find.text(DevSampleLevel.assetLabel), findsOneWidget);
  });
}
