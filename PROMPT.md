# PROMPT — Hand this to Claude Code to start the build

You are building **Market Nerve**, a mobile app (Flutter, iOS + Android) with three
connected parts:

1. **Behavioral Simulator** — the core hackathon showpiece. Users survive fast-
   forwarded historical market crashes, making Hold/Sell/Buy-the-Dip decisions at
   scripted pause points, and get graded on a Discipline Score against what the
   historically optimal move actually was.
2. **Daily Pivot** — a 10-second daily crypto prediction question that drives
   retention, with a live crowd-sentiment reveal.
3. **Time Machine** — a "what if I'd invested this instead" viral calculator with a
   shareable Instagram-story-style result graphic.

Before writing any code, read these files in order and hold them as binding spec:

1. `CLAUDE.md` — project conventions, stack, non-negotiables. Standing context for
   every session on this repo.
2. `ARCHITECTURE.md` — technical architecture across all three pillars, including
   the minimal backend the Daily Pivot requires.
3. `ENGINE.md` — the Behavioral Simulator engine: campaign + endless mode, the
   Hold/Sell/Buy decision mechanic, hidden-asset blind mode, Discipline Score.
4. `LEVELS.md` — the 15 launch levels, endless mode data strategy, data sourcing
   rules.
5. `DAILY_PIVOT.md` — the daily question mechanic, backend needs, scoring.
6. `TIME_MACHINE.md` — the calculator, share-graphic generation, growth loop.
7. `DESIGN.md` — visual system across all three tabs, what's real vs. dummy.
8. `MONETIZATION.md` — RevenueCat structure, what's free vs. Pro across pillars.
9. `ROADMAP.md` — build order and the cut list if time runs short. Follow this
   phase order.

## Ground rules for you (Claude Code) while building

- The Behavioral Simulator is one engine reused by every level (campaign and
  endless). If you're writing level-specific engine logic, stop — it belongs in
  data, not code.
- Never fabricate historical prices, dates, or "the historically optimal move" for a
  level. If LEVELS.md data is incomplete, flag it as `TODO(data)` and tell me rather
  than inventing figures — this app's entire premise depends on the history being
  real.
- The Daily Pivot's crowd-sentiment percentage is a real cross-user aggregate, not a
  simulated number — it requires the minimal backend described in ARCHITECTURE.md.
  Do not fake it with a random/local number even temporarily without flagging that
  clearly as a placeholder to swap out.
- Every "dummy" feature in DESIGN.md must be visibly present but genuinely inert —
  never crash, never silently no-op.
- No real trading, no real money, anywhere, in any of the three pillars. The
  Behavioral Simulator uses ₹1,00,000 virtual capital; make that unmistakable on
  every relevant screen.
- After each phase in ROADMAP.md, stop, give me a runnable build, and summarize
  what works, what's stubbed, and what you need from me before continuing.
- If the three-pillar scope looks like it's outrunning the time remaining, say so
  explicitly and point me at ROADMAP.md's cut list rather than silently dropping or
  half-building a pillar.

## First response I want from you

1. Confirm you've read all nine files.
2. Propose the Flutter project scaffold and the minimal backend setup (per
   ARCHITECTURE.md) for the Daily Pivot.
3. List what you need real data for before Phase 2 can start (levels) and before
   Phase 5 can start (Time Machine historical price lookups).
4. Then begin Phase 1 of ROADMAP.md.
