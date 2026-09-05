# CLAUDE.md — Project Context: Market Nerve

## What this app is
Four connected parts under one app (the fourth was added after the original
brief — see "Added later" below):
- **Behavioral Simulator** (core): fast-forwarded historical crash replays where the
  user makes a Hold/Sell/Buy-the-Dip call at scripted pause points, graded on a
  Discipline Score against the historically optimal move. Campaign (15 handcrafted
  levels) + Endless (procedural random windows from 20 years of history).
- **Daily Pivot** (retention): one daily yes/no crypto price prediction, crowd
  sentiment reveal, bonus Discipline Points for correct/contrarian calls.
- **Time Machine** (growth): a "what if" compounding calculator with a shareable
  neon result graphic, no login/gameplay required to use it.
- **Live Markets** (added later): a watchlist of real current prices across US
  equity, Indian equity and crypto, each opening a full interactive chart. Read
  only — it displays prices and cannot place an order.

Built for RevenueCat Shipaton 2026. Deadline: Sep 30, 2026, 11:45pm PT, app must be
**fully published**, not in review.

## What this app is NOT
- Not a real trading app. No real money anywhere, in any pillar, ever. Live
  Markets shows real prices; it places no orders and never will.
- Not a custom-strategy backtester. The Simulator replays history and asks you to
  act in it; it is not a programmable strategy engine.

### Revised by Somi's request (previously listed here as non-goals)
- **A TradingView-style chart is now in scope.** This file used to say most
  console chrome was intentionally dummy/locked. It is real: one chart widget
  with pan/zoom, a crosshair, four chart types, real timeframes, six indicators
  and three drawing tools, shared by every screen that draws prices. DESIGN.md's
  real/dummy map has been rewritten to match. The replacement rule is "a control
  the host cannot serve is absent, not inert".
- **Manual continuous trading is now in scope**, through advanced mode and the
  Custom Simulation. `simulation_mode.dart` had flagged this contradiction since
  advanced mode was built; it is resolved here rather than left standing.
- The Daily Pivot is not a real-money betting product — "betting against the crowd"
  earns in-app Discipline Points only, never currency or withdrawable value. Keep
  this legally and visually unambiguous.

## Stack (non-negotiable — don't propose alternatives mid-build)
- Flutter (Dart), single codebase for iOS + Android.
- State management: Riverpod.
- Charting: build on `fl_chart` / a `CustomPainter` chart, same approach across
  Simulator and Time Machine's result graphic — don't introduce a second charting
  approach for Time Machine.
- Local persistence: `shared_preferences` for progress/scores; `sqflite` only if it
  outgrows key-value storage.
- **Minimal backend (new vs. a pure-replay app):** the Daily Pivot's crowd-sentiment
  reveal requires aggregating votes across all users in near-real-time, and the
  5:00pm outcome check is a scheduled server-side job — neither can be done
  client-only. Use Firebase (Firestore for vote counts + a scheduled Cloud Function
  for the 5pm resolution check against the crypto API) as the default choice — it's
  the lowest-setup-cost option that still satisfies both needs. Do not build a
  backend for the Simulator or Time Machine; both stay fully local/bundled-data.
- Live data: public market APIs, queried at runtime, never bundled — (a) the
  Daily Pivot's 9am setup and 5pm resolution, (b) Time Machine's historical
  lookups, and (c) Live Markets and the Custom Simulation. Binance serves crypto
  (no key, real-time, 24/7); Yahoo serves US and Indian equity (no key, delayed).
  Kotak Neo is an optional per-user broker connection for real-time NSE/BSE,
  structurally in place but not finished — see `kotak_neo_provider.dart`. Not bundled/redistributed — queried live, so
  redistribution-license concerns from the Simulator's bundled datasets don't apply
  here. Respect the free-tier rate limits; cache a day's price data locally rather
  than re-querying repeatedly.
- Notifications: local scheduled notification for the 9am Daily Pivot prompt is
  sufficient for MVP — does not require push infrastructure. If the 5pm outcome also
  needs a notification, that can be a second local scheduled notification checking
  cached result, not a true push.
- Sharing: Time Machine's result graphic is rendered client-side (RepaintBoundary →
  image) and shared via `share_plus` — no server-side image generation needed.
- Monetization: RevenueCat SDK (`purchases_flutter`).

## Non-negotiables
- Behavioral Simulator is one engine, reused by every campaign level and by Endless
  mode. Levels/windows are data, never new engine code.
- Every number presented as historical fact (a level's prices, a script event's
  date, Time Machine's compounding math) must trace to a real, sourced value — never
  invented. Flag missing data instead of fabricating it.
- The Daily Pivot's crowd percentage must be a real aggregate once live, even in
  early builds — if you stub it before the backend exists, label it obviously as a
  placeholder in-code and tell Somi, don't let it look finished before it's real.
- Every screen touching virtual money must be unmistakably simulated (see
  DESIGN.md's badge/copy rules) — applies to the Simulator and, differently, to
  Time Machine's "you missed X" framing (it's illustrative math, not advice).
- **Live Markets carries the inverse label**, and it is just as non-negotiable:
  real prices, possibly delayed, no orders placeable. A user must never be
  unsure which of the two they are looking at. A Custom Simulation is real
  prices with simulated trading, so it keeps the SIMULATED badge.
- Every live number on screen must be able to say where it came from. The source
  is displayed, not assumed.
- Replaces the old dummy-chrome rule: a control the current screen cannot
  actually serve is **absent**, not present-and-inert.

## Working style for this repo
- Commit after each working phase from ROADMAP.md, not mid-feature.
- Prefer small, testable widgets over large screen files.
- When a spec file is ambiguous or missing data, stop and ask rather than inventing
  facts — especially historical prices/dates and the "optimal move" per level.
- Keep Simulator engine code, Daily Pivot logic, and Time Machine logic in separate
  top-level feature folders (ARCHITECTURE.md) — they share design tokens and the
  RevenueCat/progress services, nothing else.
