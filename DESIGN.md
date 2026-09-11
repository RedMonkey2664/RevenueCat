# DESIGN.md — Visual Design & Real vs. Dummy Feature Map

## Look and feel
Dark-mode trading-terminal aesthetic, consistent across all three tabs so the app
reads as one product, not three bolted-together features.

- Background: near-black (#0D1117-ish), not pure black.
- Candlesticks: standard green-up/red-down, thin wicks.
- One electric accent color (cyan or amber) used sparingly — replay cursor, active
  states, positive P&L/Discipline Score, and reused as the Time Machine share
  graphic's headline color for brand consistency.
- Monospace/semi-monospace font for all numbers (prices, scores, ₹ amounts,
  timestamps) everywhere in the app, including the Time Machine card — this is the
  cheapest, highest-leverage move for "feels like a serious finance app."
- Standard UI font for narrative/body text (script reveals, Daily Pivot copy).

## Screen inventory
1. **App shell** — 4-tab bottom nav: Simulator / Markets / Daily Pivot /
   Time Machine. ("Markets" is Live Markets, added with the live-data work.)
2. **Simulator: Campaign home** — 15-level map (grid, per original spec's fallback
   recommendation — see ROADMAP.md).
3. **Simulator: Endless home** — simpler entry screen, "start a random run."
4. **Simulator: Level screen** — chart + blind-mode overlay + decision panel at
   pause points. Core screen; most polish budget goes here.
5. **Simulator: Debrief** — Discipline Score, P&L, real asset/date reveal, takeaway.
6. **Daily Pivot: home** — today's question, vote buttons, sentiment reveal state.
7. **Time Machine: calculator** — inputs, computed output, share button.
8. **Paywall** — RevenueCat-driven.
9. **Profile** — cross-pillar Discipline Points total, cleared levels, Pivot streak.

## The "SIMULATED" framing (non-negotiable, see CLAUDE.md)
- Simulator: persistent badge ("SIMULATED · ₹1,00,000 virtual capital") visible
  during play and at debrief.
- Daily Pivot: clear "Discipline Points, not money" framing near the vote buttons
  and wherever points/multipliers are shown.
- Time Machine: "illustrative, not investment advice" disclosure near the output,
  and never implies future guaranteed returns (see TIME_MACHINE.md copy guardrails).
- Onboarding (2-3 screens max, shown once) states plainly across all three pillars:
  no real money, no real trading, no live brokerage, educational/illustrative only.
- **Live Markets carries the inverse disclosure.** It is the one screen whose
  numbers are real, so it must say so — real prices, possibly delayed, no orders
  placeable here — and must NOT wear a SIMULATED badge. Blurring the two is what
  would make the badge meaningless everywhere else. A Custom Simulation is the
  other way round: real prices, simulated trading, so it keeps the badge.

## Chart chrome — all real (revised)

**This section was rewritten.** It used to list most console chrome as
deliberately inert. Somi asked for a working TradingView-style chart instead, so
the dummy layer is gone from the Simulator and the rule is inverted.

One chart widget (`features/chart/pro_chart.dart`) serves the Simulator, Live
Markets and the Custom Simulation.

REAL, everywhere the chart appears: candlesticks, Heikin-Ashi, line and area;
pan, pinch-zoom, crosshair with an OHLC readout, price-axis drag and autoscale;
linear/percent/log price scales; timeframe switching; SMA, EMA and Bollinger
overlays plus volume, RSI and MACD panes; trendline, price-line and rectangle
drawing tools, anchored to time and price so they survive a timeframe change.
Plus the Simulator's own: replay speed (1x/2x/4x), the decision panel, blind
mode, Discipline Score and P&L.

**The replacement rule — absent, not inert.** A control the host cannot serve
must not appear at all. A campaign level's bars are daily, so its toolbar offers
1D/1W/1M and no intraday; a live crypto chart offers everything from 1m up. This
is the opposite of the old rule and is enforced mechanically by
`test/design/chart_controls_test.dart`, which replaced `dummy_chrome_test.dart`.

Still genuinely locked: the extra replay speeds (0.5x, 8x) named below, which
belong to the replay rather than the chart.

What has NOT changed: blind mode. During a Simulator run neither an absolute
price nor a real date may reach the screen. `BlindChartLabels` enforces it by
rebasing every value the chart renders to an index of 100, so a new chart
feature cannot leak the asset by forgetting a flag.

## Real vs. dummy — Daily Pivot & Time Machine
Both pillars are intentionally small in scope already (see their own spec files) —
there isn't a large "dummy chrome" layer to add here the way there is in the
Simulator. Resist the temptation to pad either tab with locked features just for
visual parity; a clean, working, minimal Daily Pivot/Time Machine reads better in a
demo than a padded one. If anything, a small "more assets coming soon" chip on
Time Machine's asset selector is the one reasonable dummy element, consistent with
its Simulator counterpart.

## Cross-pillar consistency notes
- Discipline Score/Points visual language (color, iconography) should be identical
  wherever it appears (Simulator debrief, Pivot reveal, Profile) — it's the thread
  tying the three pillars together as one behavioral-finance product, not three
  separate apps.
- Time Machine's share graphic should be recognizably "from" the same app as the
  Simulator's debrief screen at a glance (same accent color, same number
  typography) — this is what turns a viral share into an actual funnel back to the
  core game, per the brief's stated growth-loop intent.

## Revision — the cyan HUD (Sep 2026 wireframe set)

The wireframe screenshots Somi supplied in September supersede the mint
palette of `Market Nerve HUD.dc.html`. Same structure (rails, corner ticks,
redaction plates, scanlines), different skin:

- Palette: navy-black ground `#0A0E13`, one cyan accent `#5BC8F5` (also the
  up colour — a gain is the nominal state), amber `#F5B041` for caution,
  advanced mode and the SIMULATED framing, red `#EF5350` only for alarm and
  losses. Tokens live in `lib/app/theme.dart`; every name is unchanged.
- Type: **Inter** for every label, heading and sentence; **JetBrains Mono**
  for anything that ticks (money, clocks, points). Both are bundled variable
  fonts with the weight axis driven explicitly, and each falls back to the
  other for glyphs it lacks (Mono has no rupee sign, Inter no ✕). Barlow
  Condensed and IBM Plex Mono are removed.
- Candles: hollow up, solid down. Wicks stop at the body.
- Shared parts: `lib/app/widgets/hud.dart` (panels, corner-tick frames,
  redaction plate, HUD buttons, status pip, top bar, scanlines),
  `hud_accordion.dart`, `nerve_avatar.dart` and `feed_state.dart`.

### Feed-state grammar (artboard 1l)
One set of widgets draws live data everywhere: loading hatches the *value*
(never the row, never a spinner alone); a live or delayed figure always names
its source (`BINANCE · LIVE`, `YAHOO · DELAYED 15M` — the delay is measured
from the quote's own timestamp, never assumed); an unavailable feed keeps its
label, dashes the number and shows a red strip with RETRY; an empty list is a
job with one action. A full-pane failure is hatched red with the one fix.
Red strip = feed, red alarm = decision; they never appear together.

### Screens added or rebuilt against the wireframes
Campaign home (1f), the level screen's four states (1a–1d), the Debrief with
its four accordions (1e), the Daily Pivot's four states (1g–1j) plus
before-open and missed, the paywall (1k), feed states in Live Markets (1l),
and the **Nerve Profile** — building / locked / full, with a shareable card.

### Nerve Profile
A behavioural read built only from the player's own runs: panic threshold
(mean drawdown at the first sell of each run), crash-speed sensitivity (sell
rate in fast vs slow falls), decision speed (median seconds on a halted
tape), dip buying and learning (latest three runs vs first three). It never
compares the player with other players — the app has no data about other
players, and copy must not imply it does. Unlocks after five distinct levels;
the archetype and overall score are free, the traits are Pro.
