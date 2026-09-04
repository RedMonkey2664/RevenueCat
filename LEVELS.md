# LEVELS.md — Campaign Levels & Endless Data

## Schema

`data/simulator_levels/level_manifest.json`:

    {
      "levels": [
        { "id": "black_monday_1987", "order": 1, "locked": false,
          "difficulty": "beginner", "asset_class": "us_equity" },
        ...
      ]
    }

`asset_class` is one of: `us_equity`, `india_equity`, `crypto` — this is the field
the level map filters/badges on (see DESIGN.md — recommend a 3-way market filter
chip: International / Indian / Bitcoin, on the campaign home screen) and it's what
selects which bundled-data path applies at build time. Crypto levels still use
bundled OHLCV for blind-mode offline play, same as equity levels — a live API isn't
used for campaign levels, only for Daily Pivot and Time Machine (see those files).

`<level_id>.json` — OHLCV series:

    {
      "id": "black_monday_1987",
      "real_asset_name": "Dow Jones Industrial Average",
      "asset_class": "us_equity",
      "starting_balance": 100000,
      "candles": [ { "date": "1987-09-01", "open": ..., "high": ..., "low": ...,
                     "close": ... }, ... ]
    }

`<level_id>_script.json` — pause points (schema per ENGINE.md §2):

    {
      "id": "black_monday_1987",
      "pause_points": [
        {
          "trigger_date": "1987-10-19",
          "flash_treatment": "red_flash_hard",
          "optimal_action": "hold",
          "reveal_headline": "The Dow fell ~22% in a single day — still the
            largest one-day percentage drop in its history. The market
            recovered to its pre-crash level within about two years."
        }
      ]
    }

`trigger_date` resolves to a candle index at load time.

## ⚠ Data sourcing — hard rule, applies to every level below

Every price, date, and `optimal_action` is a factual/interpretive claim the app
teaches as truth. None of the figures below are locked-in build data — they're a
sourced *starting point* for level selection, gathered from general market-history
coverage, and several sources disagree on exact point-drops for the same event by a
few points depending on which close is cited. Before any level is built:

- Pull the actual daily OHLCV series from a proper historical data source (not the
  summary figures below) and re-verify the headline stats against it.
- Confirm the source's terms permit bundling that data inside a shipped app.
  **License-check separately per market** — an India-market (BSE/NSE) data source,
  a US-market source, and a crypto source (CoinGecko/Binance historical export) each
  have their own terms; clearance on one does not carry over to the others.
- Where sources disagree on the exact point/percentage drop, use the most
  authoritative source available (exchange data over blog aggregation) rather than
  averaging or picking whichever number sounds most dramatic.
- `optimal_action` should reflect what actually happened next (recovered → hold/buy
  was optimal; kept falling within the window → a defensible sell), not an invented
  judgment call. Flag genuinely ambiguous cases (see GameStop, below) instead of
  forcing a clean label.

## Launch level list — 20 levels, grouped by market

Three markets, kept as visibly distinct sections in-app (level map filter chips)
and in this file — the engine doesn't care about the distinction (see ENGINE.md,
one engine regardless of `asset_class`), but the player-facing framing and the
level map should make "which market am I in" obvious at a glance, since that's part
of the pitch (International + Indian + Bitcoin, not just a generic mixed list).

---

### 🌍 INTERNATIONAL MARKETS (`us_equity`) — 9 levels

**Beginner**
1. **Black Monday, Oct 19 1987** — Dow fell ~22% in one day, largest single-day %
   drop on record. Recovered within ~2 years.
2. **Flash Crash, May 6 2010** — Dow fell ~9% intraday in minutes, mostly reversed
   the same day. Tests reacting to velocity vs. a lasting move.

**Intermediate**
3. **Dot-Com Crash, 2000–2002** — Nasdaq fell ~78% peak to trough over ~2.5 years.
   Tests holding through a crash you can watch coming, day after day.
4. **Taper Tantrum, 2013** — sharp but comparatively mild selloff on Fed
   QE-tapering signals. Low fame, so blind mode genuinely tests discipline rather
   than recognition.
5. **US Debt Ceiling / S&P Downgrade, Aug 2011** — S&P fell ~17% in ~2 weeks on the
   first-ever US credit downgrade.
6. **China-Led Global Selloff, Aug 2015–Jan 2016** — Aug 24 2015 single-day fall,
   ~15% S&P drawdown over the following months, two distinct legs down — good
   multi-pause-point candidate.

**Advanced**
7. **Global Financial Crisis, 2008** — flagship International level; Lehman
   Brothers collapse as the marquee pause point, S&P fell ~57% peak to trough
   through March 2009.
8. **COVID Crash, March 2020** — S&P fell ~34% in 33 days, fastest recovery on
   record. Best single International demo level — nearly everyone lived through it.
9. **SVB / Regional Banking Crisis, March 2023** — sharp, sector-specific, fast,
   comparatively low fame — tests panic on sector-specific news rather than a
   broad-market event.

Optional 10th, flag rather than default in: **GameStop Mania, 2021** — a bubble,
not a crash. `optimal_action` here is genuinely less clean-cut (arguably the
disciplined move was not chasing the euphoria rather than reacting to a drop) — if
included, write its script/reveal copy carefully rather than forcing the same
"hold vs. panic-sell" mold as every other level.

---

### 🇮🇳 INDIAN MARKETS (`india_equity`) — 9 levels

**Beginner**
1. **Harshad Mehta Scam, Apr 1992** — Sensex fell ~570 points (~12.8%) around
   Apr 28–29 when the scam broke; broader market lost 50%+ over the following year,
   ~4-year full recovery. India's most iconic single crash — strong opener.
2. **"Black Monday" India, May 17 2004** — Sensex fell ~565 points (~11%) in a day
   on post-election coalition uncertainty; trading halted.

**Intermediate**
3. **Ketan Parekh Scam + Dot-Com, 2000–2001** — Sensex ground down to a bottom
   around 2,594, recovery by mid-2004. India's own scam-plus-bubble-burst, distinct
   story from Harshad Mehta despite the surface similarity.
4. **2007 Pre-Crisis Tremors** — sharp single-day falls (~615-620 points) on Apr 2
   and Aug 1 2007, ahead of the 2008 crash. A "false alarm before the real thing"
   level — tests overreacting to a shock that wasn't the big one.
5. **Yuan Devaluation Selloff, Aug 2015–Feb 2016** — Aug 24 2015 single-day fall
   (~5.9%), Sensex shed ~26% over the following months. India's version of the
   International list's China-led selloff, different index/data, same global
   trigger — good pairing if you want a cross-market comparison moment.
6. **Demonetisation, Nov 2016** — Sensex/Nifty fell 6%+ over four trading days after
   the Nov 8 announcement. Domestic policy shock, not a global contagion — the one
   level in the whole set with a purely internal trigger.

**Advanced**
7. **Global Financial Crisis, 2008** — Sensex fell ~61.5% peak to trough (21,206 →
   8,160); worst single day ~7.4% on Jan 21 2008. Pairs naturally with the
   International list's 2008 level for a "same crisis, two markets" contrast if
   both stay in the campaign.
8. **COVID Crash, March 2020** — Sensex fell from ~41,000 to ~25,981, recovered to
   pre-crash level within ~8 months — an even sharper V-shape than the
   International version. Best single India demo level, same reasoning as the
   International COVID level.
9. *(Reserve slot)* — a second India-specific event if a 9th is wanted beyond the
   8 above and GameStop's International slot isn't used; candidates include the
   2013 rupee-crisis-adjacent selloff or a further-verified 2025 tariff-shock event
   (flagged separately below as high scrutiny).

---

### ₿ BITCOIN / CRYPTO MARKETS (`crypto`) — 2 levels

1. **Crypto Winter, 2018** — BTC fell ~65-80% from its Dec 2017 peak through 2018.
   First crypto level, ties directly into the Daily Pivot's crypto theme so the app
   doesn't feel like an equity app with a crypto tab bolted on.
2. **Crypto Bear, 2022** — Terra/LUNA collapse into FTX-driven contagion. Distinct
   story from 2018 (fraud/contagion-driven vs. a broad speculative unwind).

Smallest of the three sections by design — crypto's usable, cleanly-sourceable
"major historical event" list is shorter than either equity market's, and the app's
crypto surface area is mostly carried by Daily Pivot and Time Machine, not the
campaign. Don't pad this section just for numeric parity with the other two.

---

**Flagged, not included above:** April 2025 tariff-shock crashes (both US and
India saw sharp single-day falls) are real and well-documented, but very recent and
still politically live — decide deliberately whether "educational history" framing
extends to an 18-month-old event, rather than defaulting it in for either market.

## Endless mode data

`data/simulator_endless/history_pool_<asset>.json` — one long daily series per
asset, ~20 years, one pool per market so Endless mode mirrors the same three-way
split as the campaign: BTC (`crypto`), S&P 500 (`us_equity`), Sensex or Nifty 50
(`india_equity`). Bundled once per asset, reused for every randomly generated
window — much lighter than curating 20 separate datasets. Same per-market licensing
caveat as the campaign levels applies to each pool.

## Debrief content (per level, campaign or endless)

- Discipline Score (0-100) and simulated portfolio P&L, shown together.
- Real asset name + real dates (blind mode reveal).
- `reveal_headline` per pause point, plus a short "what happened after" note.
- One plain-language takeaway tied to the specific decision(s) made.

## If time runs short

Trim from the bottom of each market's tier list first, not randomly — within
International: Taper Tantrum, then SVB; within Indian: the reserve 9th slot, then
2007 Tremors; within Crypto: neither should be cut, it's already the minimum viable
section. Never drop a market to zero — the three-market framing is part of the
pitch, so a lopsided 9/9/0 reads worse than a trimmed 6/6/2. Full pillar-level cut
order lives in ROADMAP.md.
