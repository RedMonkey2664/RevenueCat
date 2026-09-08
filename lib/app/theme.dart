import 'package:flutter/material.dart';

/// Design tokens for Market Nerve.
///
/// Retuned to the **tactical-ops HUD** direction from `Market Nerve HUD.dc.html`
/// (12 artboards, Sep 2026). Its thesis, in the canvas's own words: *"everything
/// is an instrument reading — mono numerics, hairline rails, corner ticks, a
/// reticle that tracks the last bar, scanlines over glass."*
///
/// Three colours carry state, and the discipline is that they never blur:
///
///   * **mint** — system nominal. Accent, positive values, advanced mode.
///   * **amber** — caution. A run in progress, the SIMULATED framing.
///   * **red** — alarm. The decision moment and negative values, nothing else.
///
/// Every token *name* here is unchanged from the previous cyan theme, so all
/// forty-odd screens pick the new direction up without edits. Only the values
/// and the two typefaces changed. New concepts the HUD introduced ([onAccent],
/// [alarmBackground], [downSoft], [caution], [AppText.display]) are additions.
///
/// Phone-first: every size is chosen for the 390 × 844 the artboards were drawn
/// at, and checked against 375 × 667.
abstract final class AppColors {
  /// The ground. Near-black, very slightly green — it is the glass the whole
  /// HUD sits behind, and a neutral black made the mint read as a sticker
  /// rather than as emitted light.
  static const Color background = Color(0xFF06080A);

  /// The decision state's ground, warmed towards red.
  ///
  /// A two-point shift nobody consciously notices and everybody feels: the
  /// whole screen goes slightly warm the instant playback halts. Used only
  /// while a pause point is live.
  static const Color alarmBackground = Color(0xFF0A0607);

  /// Raised surfaces. In the artboards these are not grey cards but faint mint
  /// washes over the ground — a .06 and a .10 tint respectively. They are
  /// pre-composited to opaque here because the system navigation bar and the
  /// app bar cannot take a translucent fill.
  static const Color surface = Color(0xFF0A1615);
  static const Color surfaceRaised = Color(0xFF0C1F1D);

  /// Panel wash for a card drawn *over* content, where translucency is right.
  static const Color panelWash = Color(0x2446F2C8);

  /// Hairline rails. Mint-tinted rather than grey, which is most of why the
  /// interface reads as instrumentation instead of as a dark-mode app.
  static const Color border = Color(0x2478FFE1);
  static const Color borderStrong = Color(0x4778FFE1);

  static const Color textPrimary = Color(0xFFDFF5EF);

  /// The secondary and faint steps are alpha, not opaque greys, so they sit
  /// correctly on the ground *and* on a washed panel. The artboards use .5–.62
  /// and .38–.45 of the same cool grey-green.
  static const Color textSecondary = Color(0x9EBED7D2);
  static const Color textFaint = Color(0x66BED7D2);

  /// System nominal. The one electric accent, used sparingly.
  static const Color accent = Color(0xFF46F2C8);

  /// Muted accent for fills sitting behind the bright one.
  static const Color accentSoft = Color(0x2446F2C8);

  /// Brightest mint, for a pressed or hovered accent only.
  static const Color accentBright = Color(0xFF8DFADF);

  /// Foreground for anything filled with [accent].
  ///
  /// Near-black with a green cast, not pure black — the canvas is specific
  /// about this and it matters at label sizes, where pure black on mint
  /// vibrates.
  static const Color onAccent = Color(0xFF04100D);

  /// Direction of price. Note that [up] and [accent] are deliberately the same
  /// mint: in this direction a gain *is* the nominal state. See the note in
  /// DESIGN.md before separating them again.
  static const Color up = Color(0xFF46F2C8);
  static const Color down = Color(0xFFFF4D4D);

  /// A softer red for large falling numerals, where full-strength red at 30pt
  /// reads as an error message rather than as a price.
  static const Color downSoft = Color(0xFFFF8080);

  /// Caution. A run in progress, and the SIMULATED framing.
  static const Color caution = Color(0xFFFFB02E);

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
/// The HUD is square. Across twelve artboards the only radii used are 3px on a
/// chip and 50% on a status dot — there is not one rounded card. Both names are
/// kept so existing call sites compile, but [cardR] is now zero.
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

  /// Ambient loops — the scanline drift, the ARMED dot, the alarm breathing.
  ///
  /// Deliberately far slower than the interaction durations: this is texture
  /// the eye should never catch moving. The artboards run these between 1.2s
  /// and 4s.
  static const Duration ambientFast = Duration(milliseconds: 1200);
  static const Duration ambient = Duration(milliseconds: 1600);
  static const Duration ambientSlow = Duration(milliseconds: 4000);
}

/// The minimum comfortable tap area on a phone. Controls may *look* smaller,
/// but their hit box must not be.
const double kMinTouchTarget = 44;

/// Typography.
///
/// Two bundled faces, no runtime fetching, so Android and iOS render numbers
/// identically:
///
///   * **Barlow Condensed** — [display] and [title]. Narrow, so a ₹1,00,000
///     fits at 30pt where a normal-width face would not, and it takes very
///     wide letter-spacing without falling apart. Every hero numeral and
///     screen title.
///   * **IBM Plex Mono** — [mono], [label] and [body]. All prose in this
///     direction is monospace, which is the canvas's "everything is an
///     instrument reading" taken literally.
///
/// Letter-spacing is in logical pixels here, where the canvas specifies `em`,
/// so the helpers derive it from the size rather than hard-coding a value that
/// would only be right at one scale.
abstract final class AppText {
  static const String displayFamily = 'BarlowCondensed';
  static const String monoFamily = 'IBMPlexMono';

  /// Body copy is monospace in this direction. Kept as a separate name because
  /// it is a design decision, not a synonym — if long-form copy moves back to
  /// a proportional face, this is the one line that changes.
  static const String uiFamily = monoFamily;

  /// Digits must not jitter as the replay ticks. Barlow Condensed is
  /// proportional, so tabular figures are requested explicitly rather than
  /// assumed.
  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// Hero numerals — portfolio value, Discipline Score, the crowd split.
  ///
  /// Barlow Condensed, tight tracking. This is the app's signature: where a
  /// figure is the point of a screen, it is set big, condensed and tabular.
  static TextStyle display({
    double size = 30,
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.textPrimary,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: displayFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      // None. Across every artboard the hero numerals set no tracking at
      // all; condensed digits already read as a column.
      letterSpacing: letterSpacing ?? 0,
      height: height,
      fontFeatures: _tabular,
    );
  }

  /// Headlines and hero labels — Barlow Condensed, modest tracking.
  ///
  /// Sentence-safe on purpose. The canvas sets Barlow Condensed at 0.14–0.24em
  /// but *only ever on uppercase labels and numerals* — there is not one
  /// sentence in it at that tracking, and 0.22em on "You are already invested."
  /// is unreadable. The wide uppercase treatment is [railLabel].
  static TextStyle title({
    double size = 22,
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w700,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: displayFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      // 0.06em, matching the canvas's own large-label tracking.
      letterSpacing: letterSpacing ?? size * 0.06,
      height: 1.1,
    );
  }

  /// The wide uppercase rail label — app-bar titles, section headers.
  ///
  /// The canvas's signature chrome: Barlow Condensed, 13–15px, w600, and
  /// tracking wide enough (0.22em) that two words read as instrumentation
  /// rather than as a heading. Always given uppercase text by the caller.
  static TextStyle railLabel({
    double size = 13,
    Color color = AppColors.accent,
    FontWeight weight = FontWeight.w600,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: displayFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing ?? size * 0.22,
      height: 1.2,
    );
  }

  /// Numbers in running text — prices, readouts, timestamps.
  static TextStyle mono({
    double size = 13,
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
      fontFeatures: _tabular,
    );
  }

  /// Narrative copy. Monospace in this direction — see [uiFamily].
  static TextStyle body({
    double size = 13,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textPrimary,
    double height = 1.6,
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

  /// The micro-readout — "DAY 14 / 130", "ASSET CLASSIFIED", "ARMED".
  ///
  /// The most-used style in the artboards by a wide margin: 9–10px monospace
  /// with generous tracking. Distinct from [title], which is the larger
  /// condensed label.
  static TextStyle label({
    Color color = AppColors.textSecondary,
    double size = 9.5,
    FontWeight weight = FontWeight.w500,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      // 0.16em.
      letterSpacing: letterSpacing ?? size * 0.16,
    );
  }
}

/// A HUD panel: a faint mint wash behind a hairline rail, square-cornered.
///
/// Replaces the previous lit-from-above gradient card. The artboards have no
/// rounded corners and no vertical gradient — depth comes from the wash and
/// the rail, which is what keeps the surface reading as glass rather than as
/// a raised object.
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
///
/// The alarm variant is what the decision panel is built from; caution marks a
/// run in progress, nominal marks a resolved or positive state.
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
      centerTitle: false,
      // The app bar carries a rail, not a shadow.
      shape: const Border(bottom: BorderSide(color: AppColors.border)),
      titleTextStyle: AppText.railLabel(),
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
  );
}
