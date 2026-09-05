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
