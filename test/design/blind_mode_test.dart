import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_nerve/features/simulator/campaign/level_repository.dart';
import 'package:market_nerve/features/simulator/engine/level_brief.dart';
import 'package:market_nerve/features/simulator/engine/level_model.dart';

import '../support/level_harness.dart';

/// The pre-play brief must inform without identifying.
///
/// This is the exact seam where a "tell the player what the level is about"
/// feature could quietly destroy blind mode (ENGINE.md §3), so the boundary is
/// asserted rather than trusted.
void main() {
  testWidgets('the start brief never names the event, asset or dates', (
    WidgetTester tester,
  ) async {
    const LevelRepository repo = LevelRepository();
    late final LevelManifestEntry entry;
    late final SimulationLevel level;

    await tester.runAsync(() async {
      final List<LevelManifestEntry> entries = await repo.loadManifest();
      entry = entries.firstWhere(
        (LevelManifestEntry e) => e.dataStatus.isPlayable,
      );
      level = await repo.loadLevel(entry);
    });

    await pumpLevelScreen(
      tester,
      level,
    );
    expect(tester.takeException(), isNull);

    String screenText() => tester
        .widgetList<Text>(find.byType(Text))
        .map((Text t) => t.data ?? '')
        .join(' | ');

    final String visible = screenText();

    // The brief is present and useful.
    expect(find.text('You are already invested.'), findsOneWidget);
    expect(visible, contains('CALLS'));
    expect(visible, contains('SEVERITY'));

    // ...but it gives nothing away.
    expect(visible, isNot(contains(entry.revealTitle)));
    expect(visible, isNot(contains(level.realAssetName)));
    expect(
      visible,
      isNot(contains(level.description!.substring(0, 30))),
      reason: 'the event story belongs to the Debrief, not the start screen',
    );
    for (final String year in <String>['1987', '2000', '2008', '2020', '2018']) {
      expect(
        visible,
        isNot(contains(year)),
        reason: 'a year on the start screen narrows the guess to one event',
      );
    }
  });

  testWidgets('the brief describes shape, never identity', (
    WidgetTester tester,
  ) async {
    const LevelRepository repo = LevelRepository();
    late final List<LevelManifestEntry> entries;
    await tester.runAsync(() async {
      entries = await repo.loadManifest();
    });

    // One playable level per market rather than all seventeen: the invariant
    // is a property of LevelBrief, not of any particular level, and parsing
    // ~900KB of candles in the test VM blows the default timeout.
    final List<LevelManifestEntry> sample = <LevelManifestEntry>[
      for (final AssetClass market in AssetClass.values)
        ...entries
            .where(
              (LevelManifestEntry e) =>
                  e.assetClass == market && e.dataStatus.isPlayable,
            )
            .take(1),
    ];
    expect(sample, hasLength(AssetClass.values.length));

    for (final LevelManifestEntry entry in sample) {
      late final SimulationLevel level;
      await tester.runAsync(() async {
        level = await repo.loadLevel(entry);
      });
      final LevelBrief brief = LevelBrief.of(level);

      expect(brief.moments, level.pausePoints.length);
      expect(brief.days, level.candles.length);
      expect(brief.approxMonths, greaterThan(0));

      final String text = '${brief.headline} ${brief.body}';
      expect(text, isNot(contains(level.realAssetName)));
      expect(text, isNot(contains(entry.revealTitle)));
    }
  });
}
