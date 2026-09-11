import 'package:flutter/material.dart';

/// Design tokens for Market Nerve.
///
/// The **tactical-ops HUD**, in its cyan revision (the wireframe set of Sep
/// 2026, which supersedes the mint palette of `Market Nerve HUD.dc.html`). The
/// structure is unchanged — "everything is an instrument reading: mono
/// numerics, hairline rails, corner ticks, scanlines over glass" — only the
/// palette and the two faces moved.
///
/// Three colours carry state, and the discipline is that they never blur:
///
///   * **cyan** — system nominal. Accent, positive values, the selected state.
///   * **amber** — caution. Advanced mode, the SIMULATED framing, streaks.
///   * **red** — alarm. The decision moment and negative values, nothing else.
///
/// Every token *name* is unchanged from the previous palettes, so the forty-odd
/// screens pick the revision up without edits.
///
/// Phone-first: every size is chosen for the 390 × 844 the wireframes were
/// drawn at, and checked against 375 × 667.
abstract final class AppColors {
  /// The ground. Near-black with a navy cast — the glass the HUD sits behind.
  static const Color background = Color(0xFF0A0E13);

  /// The decision state's ground, warmed towards red.
  ///
  /// A small shift nobody consciously notices and everybody feels: the whole
  /// screen goes warm the instant playback halts. Used only while a pause
  /// point is live.
  static const Color alarmBackground = Color(0xFF130A0C);

  /// Raised surfaces. Barely lifted off the ground — the wireframes draw
  /// panels with a rail, not with a fill.
  static const Color surface = Color(0xFF0D1319);
  static const Color surfaceRaised = Color(0xFF121A22);

  /// Panel wash for a card drawn *over* content, where translucency is right.
  static const Color panelWash = Color(0x145BC8F5);

  /// Hairline rails. Steel, cooler than the ground.
  static const Color border = Color(0xFF1C2833);
  static const Color borderStrong = Color(0xFF2B3A48);

  static const Color textPrimary = Color(0xFFE4EDF2);
  static const Color textSecondary = Color(0xFF8A98A6);
  static const Color textFaint = Color(0xFF56626E);

  /// System nominal. The one electric accent.
  static const Color accent = Color(0xFF5BC8F5);

  /// Muted accent for fills sitting behind the bright one.
  static const Color accentSoft = Color(0x295BC8F5);

  /// Brightest cyan, for a pressed or hovered accent only.
  static const Color accentBright = Color(0xFF8FDCFA);

  /// Foreground for anything filled with [accent]. Near-black with a navy
  /// cast; pure black on cyan vibrates at label sizes.
  static const Color onAccent = Color(0xFF061019);

  /// Direction of price. [up] and [accent] are deliberately the same cyan: in
  /// this direction a gain *is* the nominal state.
  static const Color up = accent;
  static const Color down = Color(0xFFEF5350);

  /// A softer red for large falling numerals, where full-strength red at 32pt
  /// reads as an error message rather than as a price.
  static const Color downSoft = Color(0xFFF28B8B);

  /// Caution. Advanced mode, streaks, and the SIMULATED framing.
  static const Color caution = Color(0xFFF5B041);

  /// Flash treatments at pause points (ENGINE.md §2).
  static const Color flashHard = down;
  static const Color flashSoft = caution;

  /// The SIMULATED badge and other non-negotiable framing chrome.
  static const Color simulatedBadge = caution;

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

/// Corner radii.
///
/// The HUD is square. The only radii in the wireframes are 3px on a chip and
/// 50% on a status dot or a level node. Both names are kept so existing call
/// sites compile, but [cardR] is zero.
abstract final class AppRadius {
  static const Radius chipR = Radius.circular(3);
  static const Radius cardR = Radius.zero;

  static const BorderRadius chip = BorderRadius.all(chipR);
  static const BorderRadius card = BorderRadius.zero;
  static const BorderRadius sheet = BorderRadius.zero;
}

/// Motion. One easing curve and three durations across the whole app —
/// inconsistent timing is the fastest way to make an interface feel cheap.
abstract final class AppMotion {
  /// Expo-out. Fast departure, soft landing.
  static const Curve curve = Cubic(0.16, 1, 0.3, 1);

  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 380);

  /// Ambient loops — the ARMED dot, the feed sweep, the alarm breathing.
  /// Far slower than interaction timing: texture the eye should never catch.
  static const Duration ambientFast = Duration(milliseconds: 1200);
  static const Duration ambient = Duration(milliseconds: 1600);
  static const Duration ambientSlow = Duration(milliseconds: 4000);
}

/// The minimum comfortable tap area on a phone. Controls may *look* smaller,
/// but their hit box must not be.
const double kMinTouchTarget = 44;

/// Typography.
///
/// Two bundled variable faces, no runtime fetching, so Android and iOS render
/// numbers identically:
///
///   * **Inter** — [headline], [title], [railLabel], [label] and [body]. The
///     wireframes set every label, heading and sentence in it, from 9pt
///     tracked caps to the 44pt Daily Pivot question.
///   * **JetBrains Mono** — [display] and [mono]. Money, clocks, readouts:
///     anything that ticks, so digits never jitter.
///
/// Both files are variable fonts. Flutter does not reliably map `fontWeight`
/// onto a variable font's `wght` axis on every platform, so each style also
/// sets the axis explicitly — without it, bold can silently render regular.
///
/// Letter-spacing is derived from the size (the wireframes specify `em`), so
/// a style stays right at every scale.
abstract final class AppText {
  static const String sansFamily = 'Inter';
  static const String monoFamily = 'JetBrainsMono';

  /// Kept as names for the two roles rather than for the two files — if a
  /// role changes face, this is the line that moves.
  static const String displayFamily = monoFamily;
  static const String uiFamily = sansFamily;

  /// A glyph a face lacks falls back to the other bundled face rather
  /// than to whatever the platform picks: JetBrains Mono has no rupee
  /// sign, Inter has no multiplication cross.
  static const List<String> _monoFallback = <String>[sansFamily];
  static const List<String> _sansFallback = <String>[monoFamily];

  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static List<FontVariation> _weight(FontWeight w) => <FontVariation>[
    FontVariation.weight(w.value.toDouble()),
  ];

  /// Hero figures that tick — portfolio value, countdowns, points.
  ///
  /// JetBrains Mono, bold, untracked: a monospaced rupee figure reads as an
  /// instrument, and it cannot shift width as the replay ticks.
  static TextStyle display({
    double size = 30,
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.textPrimary,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontFamilyFallback: _monoFallback,
      fontSize: size,
      fontWeight: weight,
      fontVariations: _weight(weight),
      color: color,
      letterSpacing: letterSpacing ?? -size * 0.01,
      height: height,
      fontFeatures: _tabular,
    );
  }

  /// Big sans headlines and verdict numerals — "YOU ARE ALREADY INVESTED.",
  /// the Discipline Score, the crowd split, "THE DEEP HOLDER".
  static TextStyle headline({
    double size = 28,
    FontWeight weight = FontWeight.w800,
    Color color = AppColors.textPrimary,
    double? letterSpacing,
    double? height = 1.08,
  }) {
    return TextStyle(
      fontFamily: sansFamily,
      fontFamilyFallback: _sansFallback,
      fontSize: size,
      fontWeight: weight,
      fontVariations: _weight(weight),
      color: color,
      letterSpacing: letterSpacing ?? size * 0.02,
      height: height,
      fontFeatures: _tabular,
    );
  }

  /// Headings and hero labels. Sentence-safe tracking.
  static TextStyle title({
    double size = 22,
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w700,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: sansFamily,
      fontFamilyFallback: _sansFallback,
      fontSize: size,
      fontWeight: weight,
      fontVariations: _weight(weight),
      color: color,
      letterSpacing: letterSpacing ?? size * 0.04,
      height: 1.15,
    );
  }

  /// The wide uppercase rail label — app-bar titles, section headers, the
  /// three decision rows. Tracking wide enough (0.2em) that two words read as
  /// instrumentation rather than as a heading. Callers pass uppercase text.
  static TextStyle railLabel({
    double size = 13,
    Color color = AppColors.accent,
    FontWeight weight = FontWeight.w700,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: sansFamily,
      fontFamilyFallback: _sansFallback,
      fontSize: size,
      fontWeight: weight,
      fontVariations: _weight(weight),
      color: color,
      letterSpacing: letterSpacing ?? size * 0.2,
      height: 1.2,
    );
  }

  /// Numbers in running text — prices, readouts, level codes.
  static TextStyle mono({
    double size = 13,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.textPrimary,
    double letterSpacing = 0,
    double? height,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontFamilyFallback: _monoFallback,
      fontSize: size,
      fontWeight: weight,
      fontVariations: _weight(weight),
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: _tabular,
    );
  }

  /// Narrative copy.
  static TextStyle body({
    double size = 13,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textPrimary,
    double height = 1.55,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: sansFamily,
      fontFamilyFallback: _sansFallback,
      fontSize: size,
      fontWeight: weight,
      fontVariations: _weight(weight),
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// The micro-readout — "DAY 14 / 130", "ASSET CLASSIFIED", "STREAK".
  ///
  /// The most-used style in the wireframes by a wide margin: small tracked
  /// caps. Callers pass uppercase text.
  static TextStyle label({
    Color color = AppColors.textSecondary,
    double size = 10,
    FontWeight weight = FontWeight.w500,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: sansFamily,
      fontFamilyFallback: _sansFallback,
      fontSize: size,
      fontWeight: weight,
      fontVariations: _weight(weight),
      color: color,
      // 0.16em.
      letterSpacing: letterSpacing ?? size * 0.16,
      fontFeatures: _tabular,
    );
  }
}

/// A HUD panel: a barely-lifted fill behind a hairline rail, square-cornered.
BoxDecoration cardDecoration({
  Color? borderColor,
  BorderRadius radius = AppRadius.card,
  bool raised = false,
}) {
  return BoxDecoration(
    color: raised ? AppColors.surfaceRaised : AppColors.surface,
    border: Border.all(color: borderColor ?? AppColors.border),
    borderRadius: radius,
  );
}

/// An emphasised panel in one of the three state colours.
BoxDecoration statePanelDecoration(
  Color stateColor, {
  double fillOpacity = 0.10,
  double borderOpacity = 0.55,
}) {
  return BoxDecoration(
    color: stateColor.withValues(alpha: fillOpacity),
    border: Border.all(color: stateColor.withValues(alpha: borderOpacity)),
  );
}

ThemeData buildAppTheme() {
  const ColorScheme scheme = ColorScheme.dark(
    surface: AppColors.background,
    primary: AppColors.accent,
    onPrimary: AppColors.onAccent,
    secondary: AppColors.caution,
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
      centerTitle: true,
      // The app bar carries a rail, not a shadow.
      shape: const Border(bottom: BorderSide(color: AppColors.border)),
      titleTextStyle: AppText.railLabel(size: 15),
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
      contentTextStyle: AppText.body(size: 12),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.chip),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionColor: AppColors.accentSoft,
      selectionHandleColor: AppColors.accent,
    ),
  );
}
