import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_nerve/core/services/progress_service.dart';
import 'package:market_nerve/features/simulator/engine/level_model.dart';
import 'package:market_nerve/features/simulator/engine/simulation_mode.dart';
import 'package:market_nerve/features/simulator/level/level_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// iPhone 14. Not the smallest target — `responsive_layout_test.dart` covers
/// the short end deliberately — but a representative one.
const Size defaultSurface = Size(390, 844);

/// Mounts the level screen the way the app does.
///
/// `sharedPreferencesProvider` is documented as "must be overridden at
/// startup", and the level screen reads it (through `chartPreferencesProvider`)
/// now that the chart's type and indicators persist. Tests that skipped the
/// override used to pass only because nothing on the screen needed it — so
/// this helper exists to keep every level-screen test wired the way `main.dart`
/// wires it, rather than each test discovering the requirement separately.
///
/// It also pins a real phone surface. The flutter_test default is 800x600 —
/// wider and *shorter* than any phone — and the level screen is a vertical
/// stack of header, chart, toolbar, transport and decision panel. Testing it
/// 240pt shorter than the smallest real target made the pre-run brief scroll
/// in tests and nowhere else.
Future<void> pumpLevelScreen(
  WidgetTester tester,
  SimulationLevel level, {
  SimulationMode mode = SimulationMode.beginner,
  Map<String, Object> prefs = const <String, Object>{},
  Size surface = defaultSurface,
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(prefs);
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: MaterialApp(home: LevelScreen(level: level, mode: mode)),
    ),
  );
  await tester.pump();
}

/// Every `Text` currently on screen, joined — used to assert that something
/// is *absent* from the whole tree, not merely absent from one widget.
String visibleText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text t) => t.data ?? '')
    .join(' | ');
