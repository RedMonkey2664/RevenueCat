import 'package:flutter/material.dart';

/// Design tokens for Market Nerve, per DESIGN.md.
///
/// One dark trading-terminal palette shared by all three pillars, so the
/// Simulator debrief, the Daily Pivot reveal and the Time Machine share card
/// read as one product.
///
/// Phone-first: every size here is chosen for a 375–430pt viewport held in one
/// hand, not for a desktop window.
abstract final class AppColors {
  /// Near-black, deliberately not pure black — DESIGN.md asks for it, and
  /// true #000 also smears on OLED during the replay's fast scrolling.
  static const Color background = Color(0xFF0B0F14);

  /// Raised surfaces. Two steps, not five: more depth than this stops reading
  /// as a terminal.
  static const Color surface = Color(0xFF141A21);
  static const Color surfaceRaised = Color(0xFF1B222B);

  /// Hairline. Low contrast on purpose — borders should organise, not shout.
  static const Color border = Color(0xFF232C36);
  static const Color borderStrong = Color(0xFF33404E);

  static const Color textPrimary = Color(0xFFE8EEF5);
  static const Color textSecondary = Color(0xFF93A1B1);
  static const Color textFaint = Color(0xFF5D6B7A);

  /// The single electric accent (DESIGN.md allows cyan or amber; cyan chosen).
  /// Used sparingly: replay cursor, active states, positive P&L, Discipline
  /// Score, and the Time Machine share headline.
  static const Color accent = Color(0xFF22D3EE);
  static const Color accentSoft = Color(0xFF0E7490);

  /// Candles and P&L. Standard green-up / red-down.
  static const Color up = Color(0xFF2DD4A7);
  static const Color down = Color(0xFFFF5C7A);

  /// Flash treatments at pause points (ENGINE.md §2).
  static const Color flashHard = Color(0xFFFF5C7A);
  static const Color flashSoft = Color(0xFFFFB020);

  /// "SIMULATED" badge and other non-negotiable framing chrome.
  static const Color simulatedBadge = Color(0xFFFFB020);

  /// Ambient wash behind hero numbers. Cheap depth, no blur cost.
  static Color glow(Color c, [double opacity = 0.18]) =>
      c.withValues(alpha: opacity);
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Corner radii. Cards are soft; terminal chips stay tight, so the console
/// still reads as instrumentation rather than as a consumer app.
abstract final class AppRadius {
  static const Radius chipR = Radius.circular(6);
  static const Radius cardR = Radius.circular(14);

  static const BorderRadius chip = BorderRadius.all(chipR);
  static const BorderRadius card = BorderRadius.all(cardR);
  static const BorderRadius sheet = BorderRadius.vertical(top: cardR);
}

/// Motion. One easing curve and three durations across the whole app —
/// inconsistent timing is the fastest way to make an interface feel cheap.
abstract final class AppMotion {
  /// Expo-out. Fast departure, soft landing.
  static const Curve curve = Cubic(0.16, 1, 0.3, 1);

  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 380);
}

/// The minimum comfortable tap area on a phone. Controls may *look* smaller,
/// but their hit box must not be.
const double kMinTouchTarget = 44;

/// Typography.
///
/// DESIGN.md: monospace for every number (prices, scores, rupee amounts,
/// timestamps) app-wide; the standard UI font for narrative copy.
///
/// Both faces are bundled variable fonts, so Android and iOS render numbers
/// identically and nothing is fetched at runtime.
abstract final class AppText {
  static const String monoFamily = 'JetBrainsMono';
  static const String uiFamily = 'Inter';

  static TextStyle mono({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.textPrimary,
    double letterSpacing = 0,
    double? height,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      // Digits must not jitter as the replay ticks.
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
  }

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textPrimary,
    double height = 1.45,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: uiFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Section heading.
  static TextStyle title({
    double size = 22,
    Color color = AppColors.textPrimary,
  }) {
    return TextStyle(
      fontFamily: uiFamily,
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: color,
      height: 1.2,
      letterSpacing: -0.4,
    );
  }

  /// Small all-caps label used for console chrome ("DAY 14", "SIMULATED").
  static TextStyle label({
    Color color = AppColors.textSecondary,
    double size = 10,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: 1.1,
    );
  }
}

/// Standard card surface: a soft vertical gradient plus a hairline top
/// highlight. Reads as lit from above without costing a blur pass.
BoxDecoration cardDecoration({
  Color? borderColor,
  BorderRadius radius = AppRadius.card,
  bool raised = false,
}) {
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: raised
          ? <Color>[AppColors.surfaceRaised, AppColors.surface]
          : <Color>[AppColors.surface, AppColors.background],
    ),
    border: Border.all(color: borderColor ?? AppColors.border),
    borderRadius: radius,
  );
}

ThemeData buildAppTheme() {
  const ColorScheme scheme = ColorScheme.dark(
    surface: AppColors.background,
    primary: AppColors.accent,
    onPrimary: AppColors.background,
    secondary: AppColors.accent,
    error: AppColors.down,
    onSurface: AppColors.textPrimary,
    outline: AppColors.border,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: AppText.uiFamily,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    dividerColor: AppColors.border,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.label(color: AppColors.textPrimary, size: 11),
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 22),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceRaised,
      contentTextStyle: AppText.body(size: 13),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.chip),
    ),
  );
}
