import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_nerve/core/services/progress_service.dart';
import 'package:market_nerve/features/simulator/engine/simulation_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> containerWith(
    Map<String, Object> initial,
  ) async {
    SharedPreferences.setMockInitialValues(initial);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final ProviderContainer container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('starts empty', () async {
    final ProviderContainer c = await containerWith(<String, Object>{});
    final ProgressState state = c.read(progressProvider);

    expect(state.levels, isEmpty);
    expect(state.clearedCount, 0);
    expect(state.totalDisciplinePoints, 0);
  });

  test('records a run and exposes it as cleared', () async {
    final ProviderContainer c = await containerWith(<String, Object>{});
    await c.read(progressProvider.notifier).recordRun(
          levelId: 'gfc_2008',
          score: 72,
          pnl: -1500,
          mode: SimulationMode.beginner,
        );

    final ProgressState state = c.read(progressProvider);
    expect(state.clearedCount, 1);
    expect(state.forLevel('gfc_2008')!.bestScore, 72);
    expect(state.forLevel('gfc_2008')!.timesPlayed, 1);
    expect(state.totalDisciplinePoints, 72);
  });

  test('keeps the best score, not the latest', () async {
    final ProviderContainer c = await containerWith(<String, Object>{});
    final ProgressNotifier notifier = c.read(progressProvider.notifier);

    await notifier.recordRun(
      levelId: 'gfc_2008',
      score: 80,
      pnl: 100,
      mode: SimulationMode.beginner,
    );
    await notifier.recordRun(
      levelId: 'gfc_2008',
      score: 40,
      pnl: -100,
      mode: SimulationMode.advanced,
    );

    final ProgressState state = c.read(progressProvider);
    expect(state.forLevel('gfc_2008')!.bestScore, 80);
    expect(state.forLevel('gfc_2008')!.timesPlayed, 2);
    expect(
      state.forLevel('gfc_2008')!.modesPlayed,
      containsAll(<String>['beginner', 'advanced']),
    );
  });

  test('replaying the same level does not farm points', () async {
    final ProviderContainer c = await containerWith(<String, Object>{});
    final ProgressNotifier notifier = c.read(progressProvider.notifier);

    for (int i = 0; i < 5; i++) {
      await notifier.recordRun(
        levelId: 'gfc_2008',
        score: 60,
        pnl: 0,
        mode: SimulationMode.beginner,
      );
    }

    expect(
      c.read(progressProvider).totalDisciplinePoints,
      60,
      reason: 'the total is the sum of best scores, not of every run',
    );
  });

  test('an ungraded run still counts as played', () async {
    final ProviderContainer c = await containerWith(<String, Object>{});
    await c.read(progressProvider.notifier).recordRun(
          levelId: 'quiet_window',
          score: null,
          pnl: 250,
          mode: SimulationMode.advanced,
        );

    final ProgressState state = c.read(progressProvider);
    expect(state.forLevel('quiet_window')!.isCleared, isTrue);
    expect(state.forLevel('quiet_window')!.bestScore, isNull);
    expect(state.totalDisciplinePoints, 0);
  });

  test('survives a restart', () async {
    final ProviderContainer first = await containerWith(<String, Object>{});
    await first.read(progressProvider.notifier).recordRun(
          levelId: 'covid_crash_2020',
          score: 91,
          pnl: 4200,
          mode: SimulationMode.beginner,
        );

    // A fresh container over the same backing store is what a relaunch looks
    // like from the app's point of view.
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final ProviderContainer second = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(second.dispose);

    final ProgressState state = second.read(progressProvider);
    expect(state.forLevel('covid_crash_2020')!.bestScore, 91);
    expect(state.totalDisciplinePoints, 91);
  });

  test('corrupt stored data does not block play', () async {
    final ProviderContainer c = await containerWith(<String, Object>{
      'mn.progress.levels.v1': 'not json at all',
    });

    expect(c.read(progressProvider).levels, isEmpty);
  });

  test('Daily Pivot points feed the same total', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'mn.progress.pivot_points.v1': 30,
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final ProviderContainer c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);

    await c.read(progressProvider.notifier).recordRun(
          levelId: 'gfc_2008',
          score: 50,
          pnl: 0,
          mode: SimulationMode.beginner,
        );

    expect(c.read(progressProvider).totalDisciplinePoints, 80);
  });
}
