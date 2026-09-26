# Data sources and their licence status

Every dataset the app ships or fetches, where it came from, and whether we
are actually allowed to do what we are doing with it. Written plainly
because the honest answer for some of it is "not verified".

## Summary

| Source | Used for | Bundled or fetched | Redistribution status |
|---|---|---|---|
| Yahoo Finance | US and Indian equity: campaign levels, Live Markets, Time Machine, Custom Simulation | Both | **Not cleared.** Terms forbid redistribution |
| Binance public market data | Crypto: campaign levels, Endless pool, Daily Pivot, Live Markets | Both | **Not verified.** Terms need a read |
| Inter | UI typeface | Bundled | SIL OFL 1.1 — cleared |
| JetBrains Mono | Numeric typeface | Bundled | SIL OFL 1.1 — cleared |
| Mascot clips | Loading and onboarding | Bundled | Generated for this project |

## The problem, stated plainly

**Fetching is fine. Bundling is the question.** Calling a public endpoint at
runtime to show a price is ordinary app behaviour. Shipping a copy of that
provider's historical series inside an app binary is redistribution, and
that is what `data/simulator_levels/` does for all 17 campaign levels and
what `data/simulator_endless/` does for the Endless pool.

`level_manifest.json` has said so since the importer was written. Every
sourced level carries `licence: unverified`, and the manifest's own comment
reads: *"NOTHING is 'cleared' yet. Equity levels come from Yahoo (terms
forbid redistribution) and index levels are the provider's IP."*

This blocks **publishing**, not building or demoing.

## Bundled datasets

`data/simulator_levels/` — 17 levels, each a price file and a script file.
Derived by `tool/import_yahoo_level.dart` and
`tool/import_binance_level.dart` from the provider series. Daily OHLC only.

`data/simulator_endless/history_pool_crypto.json` — long-run crypto history
for Endless windows, built by `tool/build_history_pool.dart`.

## Options, for the owner to choose

1. **Swap the equity levels to a clearly licensed source.** Stooq and FRED
   publish index series on terms that permit redistribution. The importers
   already isolate the fetch step, so this is a data change, not a code
   rewrite. Best outcome; costs a re-import and a re-validation run.
2. **Fetch on first launch instead of bundling.** Removes redistribution
   entirely, but breaks the offline promise the Simulator is built on and
   makes a cold start depend on Yahoo.
3. **Ship only derived statistics.** Not viable: the product replays the
   tape candle by candle.
4. **Read Binance's terms and clear the crypto levels only.** Would let the
   two free levels (Black Monday 1987 is equity; Crypto Winter 2018 is
   Binance) be partially resolved. Smallest useful step.

**Recommendation: option 1 for the equity levels, and read Binance's market
data terms for the crypto ones.** Until one of those is done, the app is
demo-ready and not publish-ready, and no claim of redistribution rights
should appear anywhere.

## Attribution in the app

Every live price names its provider on screen and says whether it is
delayed (`SourceTag`, driven by the provider, not hardcoded). The About
screen repeats it. Font licences ship in the app's licence page via
`showLicensePage`, and `assets/fonts/OFL.txt` is in the repository.
