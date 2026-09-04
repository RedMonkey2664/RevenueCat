# CLAUDE.md — Project Context: Market Nerve

## What this app is
Three connected parts under one app:
- **Behavioral Simulator** (core): fast-forwarded historical crash replays where the
  user makes a Hold/Sell/Buy-the-Dip call at scripted pause points, graded on a
  Discipline Score against the historically optimal move. Campaign (15 handcrafted
  levels) + Endless (procedural random windows from 20 years of history).
- **Daily Pivot** (retention): one daily yes/no crypto price prediction, crowd
  sentiment reveal, bonus Discipline Points for correct/contrarian calls.
- **Time Machine** (growth): a "what if" compounding calculator with a shareable
  neon result graphic, no login/gameplay required to use it.

Built for RevenueCat Shipaton 2026. Deadline: Sep 30, 2026, 11:45pm PT, app must be
**fully published**, not in review.

## What this app is NOT
- Not a real trading app. No real money anywhere in any of the three pillars.
- Not a full TradingView clone in the Simulator — it looks like a trading console;
  most console chrome beyond the core decision-and-score loop is intentionally
  dummy/locked (see DESIGN.md).
- Not a custom-strategy backtester. The Simulator is decision-at-a-pause-point, not
  manual continuous trading and not a programmable strategy engine.
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
- Live data: CoinGecko (or Binance) public API, used live at query time for (a) the
  Daily Pivot's 9am question setup and 5pm resolution, and (b) Time Machine's
  historical price lookups. Not bundled/redistributed — queried live, so
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
- Dummy/locked console features must be visibly present, tappable, and clearly
  labeled — never silently missing, never crash-on-tap.

## Working style for this repo
- Commit after each working phase from ROADMAP.md, not mid-feature.
- Prefer small, testable widgets over large screen files.
- When a spec file is ambiguous or missing data, stop and ask rather than inventing
  facts — especially historical prices/dates and the "optimal move" per level.
- Keep Simulator engine code, Daily Pivot logic, and Time Machine logic in separate
  top-level feature folders (ARCHITECTURE.md) — they share design tokens and the
  RevenueCat/progress services, nothing else.
