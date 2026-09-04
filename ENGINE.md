# ENGINE.md — The Behavioral Simulator Engine

This is the core hackathon showpiece. One engine, reused by all 15 campaign levels
and by Endless mode's procedurally chosen windows. If a "new level" ever needs new
engine code, that's a design failure — fix the engine's generality instead.

## 1. ReplayController (real, must feel great)
- Holds the candle array for the current level/window.
- `currentIndex`, `play()`, `pause()`, `scrubTo(index)` (scrub mainly used at
  debrief for review, not during the timed play-through), `setSpeed()`.
- Advances fast enough that "weeks of data in seconds" actually reads as fast-
  forward, not a slow crawl — tune real playback speed by testing on a device, not
  by guessing a number.
- On reaching a pause index (see §2), auto-pauses and hands control to the
  Decision flow — this is different from CrashCourse-style free scrubbing; the
  Simulator is a guided sequence, not a free-scrub sandbox.

## 2. Pause points & the Decision mechanic (real, this is the whole game)

Each level's script defines one or more pause points:

    PausePoint {
      int triggerIndex
      String flashTreatment        // e.g. "red_flash_hard" vs "amber_flash_soft"
      String optimalAction         // "hold" | "sell" | "buy_dip"
      String revealHeadline        // shown at debrief, e.g. "This was the 2018
                                    // Crypto Winter bottom — historically, holding
                                    // recovered within 14 months."
    }

At `triggerIndex`: screen does the flash/pause treatment (DESIGN.md), portfolio
value visibly plummeting on screen, then `decision_panel` presents exactly three
buttons: **Hold**, **Sell All**, **Buy the Dip**. No time pressure countdown is
required for MVP (adds complexity for uncertain payoff) — a deliberate pause with no
timer is fine and arguably more honest to the "the discipline is the point" theme;
add a countdown only if time remains after Phase 3 of ROADMAP.md.

Recording a decision does not end the level — playback resumes and can include more
than one pause point per level (a level can test discipline more than once, e.g. an
initial crash and a subsequent dead-cat bounce).

## 3. Blind Mode (real, cheap to build, high value)
- Asset name and real dates are hidden throughout play — chart shows relative price
  action and a relative day counter ("Day 14 of simulation") only.
- This is what makes campaign levels replayable as genuine tests rather than
  "oh I remember this chart" — keep it strict; nothing on the level screen during
  play should let a user infer which real event it is.
- Reveal happens only at Debrief: real asset, real dates, `revealHeadline` per pause
  point, and the historical context.

## 4. Discipline Score (real)
- Per pause point: compare user's choice to `optimalAction`.
  - Match → full points for that pause point.
  - "Hold" chosen when optimal was "buy_dip" (or vice versa) → partial credit —
    both are non-panic responses, so weight them closer together than either is to
    "sell".
  - "Sell All" chosen when optimal was "hold" or "buy_dip" → zero/lowest credit —
    this is the panic-sell case the whole app is built to discourage.
- Level score = sum across pause points, normalized to a 0-100 Discipline Score
  shown at Debrief alongside the portfolio's actual simulated P&L (both matter: the
  score is behavioral, the P&L is the tangible consequence of that behavior).
- Running total Discipline Points (across all levels + Daily Pivot bonuses, see
  DAILY_PIVOT.md) is the cross-app profile stat — store in `progress_service`.

## 5. Campaign mode (real)
- 15 handcrafted levels (see LEVELS.md), fixed order or a light unlock curve (don't
  over-engineer branching — linear unlock is fine for MVP).
- Each level bundled: OHLCV data file, script file (pause points + reveal content).

## 6. Endless mode (real, but simplest viable version)
- Unlocks after campaign is cleared (or after N campaign levels, if full-campaign-
  gate proves too slow for demo purposes — decide based on Phase timing, not upfront).
- `endless_generator.dart`: given a bundled long-run price history per asset
  (`data/simulator_endless/history_pool_<asset>.json`, ~20 years daily), picks a
  random 6-month window, and **auto-detects pause points** rather than requiring
  hand-authored scripts — e.g. flag the window's single largest N-day peak-to-trough
  drawdown as the pause point, with `optimalAction` derived mechanically (if price
  recovered above pre-drawdown level within the remaining window, optimal = hold; if
  it kept falling, optimal = a defensible sell — document the exact rule in code,
  don't leave it fuzzy). This is the one piece of "real" logic that's genuinely new
  vs. campaign mode; keep the detection rule simple and testable rather than
  building anything resembling real technical analysis.
- No blind-mode reveal content for endless windows beyond "here's what the asset and
  dates actually were" — no curated historical narrative needed here, that's what
  campaign mode is for.

## 7. Chart chrome — real vs. dummy
Same principle as before: the chart should *look* like a trading console, but only
candlestick rendering + the two core indicators are real.
- REAL: candlestick chart, SMA (20) and RSI (14) toggle, replay speed control.
- DUMMY/LOCKED: other chart types (line, Heikin-Ashi), other timeframes, other
  indicators (MACD, Bollinger, Volume Profile), drawing tools, order-type selectors.
  See DESIGN.md for the full map and the mechanical definition of "dummy."
