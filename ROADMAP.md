# ROADMAP.md — Build Order

Context: Sep 30, 11:45pm PT deadline, must be **fully published**, not in review.
That's roughly a month from today, minus store review buffer. Three pillars is
meaningfully more scope than a single-pillar app — read the cut list at the bottom
before committing to building all three at full depth.

Before Phase 1, confirm outside of Claude Code (Somi):
- Google Play account status (new personal accounts face a 2-week closed testing
  rule before full release — changes how late Phase 8 can start).
- A legally bundleable historical data source for the 15 campaign levels + the
  endless-mode history pools.
- Firebase project created (free tier is sufficient for Daily Pivot's scale here).

## Phase 0 — Scaffold (½ day)
- Flutter project init, 3-tab shell, folder structure per ARCHITECTURE.md.
- Riverpod, fl_chart, shared_preferences, purchases_flutter, share_plus,
  flutter_local_notifications, firebase_core/cloud_firestore added.
- Firebase project wired (empty Firestore, no Cloud Functions yet).

## Phase 1 — Simulator engine core (2-3 days)
- `ReplayController` + candlestick `ChartView`, pause-at-index behavior, blind mode
  hiding symbol/date, against one hardcoded sample dataset.
- Get the flash-pause-decision *feel* right before anything else — this is the
  product's emotional core and the main hackathon demo moment.

## Phase 2 — Decision mechanic + one real campaign level (2-3 days)
- `decision_panel` (Hold/Sell All/Buy the Dip), `discipline_score.dart`.
- One real level end to end: load data/script → play → pause/decide → Debrief with
  real Discipline Score + P&L + reveal.
- Exit criterion: one full level genuinely playable on a device. Remaining campaign
  levels are repetition of this, not new hard problems.

## Phase 3 — Remaining campaign levels + level map (3-4 days)
- Author/verify data + script files for the rest of the 15 levels (or however many
  survive the cut list below).
- Campaign level-map grid with lock state from `level_manifest.json`.

## Phase 4 — Endless mode (1-2 days)
- Bundle the 20-year history pool(s), build `endless_generator.dart`'s window-pick +
  auto-detected pause point logic (ENGINE.md §6).
- This is small if Phase 1-3's engine is properly generic — if it isn't, that's a
  sign to go back and generalize before building Endless, not to special-case it.

## Phase 5 — Time Machine (1-2 days)
- Fully independent of the Simulator's engine — can be built in parallel with
  Phase 3/4 if more than one person is working on this.
- Calculator + live price lookup + share graphic + `share_plus` export.

## Phase 6 — Daily Pivot (2-3 days)
- Firestore schema (today's question, vote tally, resolved outcome).
- Two Cloud Functions: 9am question setup, 5pm resolution.
- Client: vote flow, sentiment reveal, Discipline Points award, 9am local
  notification.
- Budget real time for this despite it being "just a yes/no question" — it's the
  one pillar with a live backend dependency and the most new moving parts relative
  to its apparent simplicity.

## Phase 7 — Dummy chrome + design pass (2 days)
- Simulator's locked chart chrome (DESIGN.md) via a reusable `LockedFeatureChip`.
- Cross-pillar visual consistency pass: accent color, number typography, Discipline
  Score/Points visual language identical across Simulator/Pivot/Profile.
- SIMULATED/illustrative framing present everywhere required (CLAUDE.md/DESIGN.md).

## Phase 7b — Live Markets, Custom Simulation, pro chart (DONE)
Added after the original plan, at Somi's request, and built before Phase 8.
- Shared `features/chart/` — one interactive chart for every screen that draws
  prices. Replaces the fl_chart view and DESIGN.md's dummy console chrome.
- `core/market/` — provider abstraction over Binance (crypto) and Yahoo (equity),
  with routing, caching and de-duplication. Kotak Neo is structurally present but
  its wire calls need the official API spec before they can be written.
- Live Markets tab; Custom Simulation over any instrument, range and timeframe.

Open items carried forward:
- Kotak Neo: needs the consumer key/secret and the endpoint documentation.
- Yahoo is queried live rather than bundled, which is materially lower-risk than
  the campaign levels — but it is not a clearance. Same unresolved question as
  the levels, in a milder form.

## Phase 8 — RevenueCat + store submission prep (2-3 days)
- Full MONETIZATION.md checklist: offerings, entitlement gates (campaign lock,
  endless lock only), paywall, restore purchases, sandbox-test both platforms.
- Store listing: icon, screenshots (a Simulator pause-point screen as hero shot, a
  Time Machine share card as a secondary shot), privacy policy page (needed even
  though there's no real financial data — both stores require one; note Firebase
  usage in it).
- Submit to TestFlight / Play internal testing as early in this phase as possible.

## Phase 9 — Buffer + demo prep (remaining time)
- Fix review feedback.
- Record demo once the store listing is live — lead with a Simulator pause-point
  moment (the emotional hook), show the Debrief reveal, then Daily Pivot's crowd
  reveal, then a Time Machine share card. In that order: core game first, growth
  loop last, since judges care most about the primary mechanic.

## Cut list if time runs short (in priority order — cut top of list first)
1. Trim campaign levels from 15 to 8-10 — fewer well-sourced levels beats a padded
   15 with shaky data (same principle as the original spec).
2. Cut Endless mode entirely for launch, ship it as a stated "coming in an update"
   — campaign mode alone is a complete, demoable product.
3. Simplify Daily Pivot's 5pm resolution to a single manual/scheduled check rather
   than a polished Cloud Function pipeline, or cut the contrarian multiplier (keep
   base scoring only).
4. Cut RSI, ship SMA only, on the Simulator chart.
5. Cut the second (5pm) Daily Pivot notification — keep only the 9am prompt.
6. Simplify Time Machine to BTC-only with no asset selector at all (already the MVP
   default — just don't add more assets even if time seems to allow it).
Do not cut: the Simulator's core decision-and-score loop (Phase 1-2), the
SIMULATED/illustrative framing (store-review risk), or RevenueCat integration
(disqualifying if missing). If forced to choose between finishing Daily Pivot and
finishing Time Machine, keep Time Machine — it requires no backend and is lower
total risk to ship cleanly in the time remaining.
