# DAILY_PIVOT.md — The Daily Call

Purpose: a 10-second daily habit loop, not a second game. Resist scope creep here —
if it's taking more than a small fraction of build time, it's over-built for what
it's meant to do (see ROADMAP.md cut list, where this pillar is a prime simplify
target).

## The question
- One question per day, crypto-only (per the original brief — stock APIs are
  closed on weekends, crypto is 24/7): "Will [BTC] cross ₹[X] by 5:00 PM today?"
  (or the local-currency-equivalent framing; keep units consistent with the rest of
  the app, which otherwise uses ₹).
- Question generation for MVP: a simple rule (e.g. current price ± a fixed % band,
  set at 9am) rather than anything hand-curated daily — this needs to run
  unattended. Document the exact rule in `resolvePivot.js`/the 9am-setup function so
  it's auditable, not a black box.
- One asset for MVP (BTC). Do not build a multi-asset rotation for launch — that's a
  natural "Pro" or v2 feature, not a v1 requirement.

## Backend requirement (see ARCHITECTURE.md)
This is the one pillar that isn't purely local:
- **9:00am (scheduled Cloud Function or simple scheduled logic):** fetch current BTC
  price from CoinGecko/Binance, compute the day's question threshold, write it to
  Firestore as `today's question`.
- **Client, all day:** read the question + live vote tally; user votes once (Yes/No);
  write increments the tally; dedupe by anonymous Firebase UID so one vote per user
  per day.
- **5:00pm (scheduled Cloud Function):** query the API once, compare actual price to
  threshold, write the resolved outcome + final vote tally to Firestore.
- **Client, after 5pm (next open or a second local notification):** read resolved
  outcome, award Discipline Points via `progress_service`.

Keep the Cloud Functions minimal — two scheduled functions, both doing one API call
and one Firestore write each. Do not build anything more elaborate (no historical
question archive UI, no leaderboard) for MVP.

## The social hook
- Immediately after voting, reveal the live crowd split (e.g. "82% voted YES — you're
  betting against the crowd" / "You're with the majority"). This requires the
  Firestore tally to be genuinely live at that moment, not cached from earlier in
  the day — a single Firestore read at vote-time is sufficient, no need for a
  real-time listener/websocket for MVP.
- Contrarian framing is a copy/UX detail (a distinct color or icon state for
  "against the crowd"), not new logic.

## Scoring
- Correct guess: base Discipline Points.
- Correct **and** against the majority at vote time: multiplier (e.g. 2x) — reward
  conviction, not just being right, which is the behavioral-finance point of this
  feature tying back into the Simulator's theme.
- Incorrect guess: no points, no penalty (don't punish participation — the goal is
  daily engagement, not another source of loss-aversion pressure).
- Points feed the same `progress_service` total as the Simulator's Discipline Score,
  so a user's profile reflects both.

## Notifications
- One local scheduled notification at 9:00am prompting the day's question. Local
  scheduling (`flutter_local_notifications` or platform equivalent) is sufficient —
  this does not require a true push-notification service for MVP, since the content
  is the same daily prompt, not personalized.
- A second, optional local notification around/after 5pm for the reveal is a nice-
  to-have, not a launch requirement — cut first if time is short.

## Explicit non-goals for MVP
- No multi-asset questions, no streak-based question difficulty, no leaderboard
  across users, no push (server-triggered) notifications, no historical
  question/answer archive screen.
