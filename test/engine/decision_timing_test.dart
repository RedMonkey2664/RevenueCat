import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:histox/features/simulator/engine/candle_model.dart';
import 'package:histox/features/simulator/engine/level_model.dart';
import 'package:histox/features/simulator/engine/replay_controller.dart';
import 'package:histox/features/simulator/engine/script_event_model.dart';
import 'package:histox/features/simulator/engine/simulation_mode.dart';

/// The Nerve Profile's decision-speed trait reads how long the player looked
/// at a halted tape. That number has to be the real time between the halt and
/// the call — measured by the engine, not guessed by the screen.
void main() {
  test('a decision records the time since playback halted', () {
    final SimulationLevel level = SimulationLevel(
      id: 'timing',
      realAssetName: 'Timing fixture',
      startingBalance: 100000,
      candles: <Candle>[
        for (int i = 0; i < 5; i++)
          Candle(
            date: DateTime.utc(2020, 1, i + 1),
            open: 100,
            high: 101,
            low: 99,
            close: 100 - i.toDouble(),
          ),
      ],
      // A pause point on the first candle halts as soon as play is pressed.
      pausePoints: const <PausePoint>[
        PausePoint(
          triggerIndex: 0,
          flashTreatment: FlashTreatment.redFlashHard,
          optimalAction: DecisionAction.hold,
          revealHeadline: 'fixture',
        ),
      ],
    );

    final ProviderContainer c = ProviderContainer(
      overrides: [
        currentLevelProvider.overrideWithValue(level),
        currentModeProvider.overrideWithValue(SimulationMode.beginner),
      ],
    );
    addTearDown(c.dispose);

    final ReplayController controller = c.read(
      replayControllerProvider.notifier,
    );
    DateTime now = DateTime.utc(2026, 9, 11, 12);
    controller.clock = () => now;

    controller.play();
    expect(c.read(replayControllerProvider).isAwaitingDecision, isTrue);

    now = now.add(const Duration(seconds: 7, milliseconds: 250));
    controller.submitDecision(DecisionAction.hold);
    controller.pause();

    final RecordedDecision d = c
        .read(replayControllerProvider)
        .decisions
        .single;
    expect(d.timeToDecide, const Duration(seconds: 7, milliseconds: 250));
  });
}
