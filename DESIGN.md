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
1. **App shell** — 3-tab bottom nav: Simulator / Daily Pivot / Time Machine.
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

## Real vs. dummy — Simulator (chart chrome)

REAL: candlestick chart (one timeframe), SMA + RSI toggle, replay speed (1x/2x/4x),
Hold/Sell All/Buy the Dip decision panel, blind-mode hide/reveal, Discipline Score +
P&L computation, campaign level map, endless mode window generation.

DUMMY/LOCKED (visible, tappable, clearly inert — never silently missing, never
crash): additional chart types (Line, Heikin-Ashi, Bar), additional timeframes
(1m/5m/1H/1W next to the real 1D), additional indicators (MACD, Bollinger Bands,
Volume Profile), drawing tools (trendline/rectangle/annotation icons that open a
"Coming soon" state), a watchlist/multi-symbol switcher implying more markets exist,
extra replay speeds (0.5x, 8x+) alongside the three real ones.

Rule of thumb: if it's core to the decision-under-pressure feeling, it's real. If
it's console chrome that makes the screen *look* like a full terminal without being
load-bearing for the game, it's a dummy candidate.

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
