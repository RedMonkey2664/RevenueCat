import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/phone_frame.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'core/services/progress_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only: the Simulator's decision panel and the 9:16 Time Machine
  // share card are both designed for one orientation.
  SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
    ),
  );

  // Progress is read synchronously all over the app, so it is resolved once
  // here and injected rather than being an AsyncValue every screen unwraps.
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MarketNerveApp(),
    ),
  );
}

class MarketNerveApp extends StatelessWidget {
  const MarketNerveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Market Nerve',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // Wraps the navigator, so pushed routes and dialogs are framed too.
      builder: (BuildContext context, Widget? child) =>
          PhoneFrame(child: child ?? const SizedBox.shrink()),
      home: const AppRoot(),
    );
  }
}
