# ARCHITECTURE.md

## High-level shape

    ┌────────────────────────────────────────────────────────────┐
    │                       App Shell (4 tabs)                    │
    │  Simulator | Markets | Daily Pivot | Time Machine           │
    │  (Campaign / Endless / Custom)                              │
    └───────┬──────────────────────┬───────────────────┬─────────┘
            │                      │                   │
    ┌───────┴───────┐    ┌─────────┴────────┐  ┌───────┴────────┐
    │ SIMULATOR      │    │  DAILY PIVOT      │  │  TIME MACHINE   │
    │ ENGINE          │    │  (needs backend)  │  │  (client-only)  │
    │ (fully local,   │    │                    │  │                  │
    │  bundled data)  │    │  Firestore: votes  │  │  Live API query  │
    │                  │    │  Cloud Fn: 5pm     │  │  → local compute │
    │                  │    │  resolution check  │  │  → share image   │
    └───────┬───────┘    └─────────┬────────┘  └───────┬────────┘
            │                      │                   │
            └──────────┬───────────┴───────────┬───────┘
                        │                       │
                ┌───────┴───────┐      ┌────────┴────────┐
                │ Progress/Score │      │ RevenueCat gate  │
                │ (local)        │      │ (all 3 pillars)  │
                └───────────────┘      └─────────────────┘

Only the Daily Pivot touches a backend **of ours**. That rule stands: no server
we deploy, outside the Pivot's Firestore and its two scheduled functions.

**Revised:** this document used to say the Simulator was fully local and must
stay that way. Live Markets and the Custom Simulation both query market data at
runtime, and the Custom Simulation feeds that data straight into the Simulator's
engine. That is a live *data source*, not a backend — the same posture
CLAUDE.md already accepts for Time Machine ("queried live, not bundled"). The
campaign and Endless modes remain fully offline on bundled data, which is what
blind mode needs.

    core/market/  ── MarketDataService ── Binance   (crypto, real-time)
                                       ├─ Yahoo     (US + India equity, delayed)
                                       └─ KotakNeo  (India, opt-in, unfinished)

The service is the only thing that talks to a provider. Screens ask it, never a
provider directly, so replacing a source for a market is one change in
`_providerFor`.

## Folder structure

    lib/
      main.dart
      app/
        router.dart              # 3-tab shell
        theme.dart                # DESIGN.md tokens
      core/
        indicators/
          indicators.dart         # SMA/EMA/RSI/Bollinger/MACD — shared by chart + engine
        market/
          candle.dart             # the one bar model, re-exported by the engine
          bar_interval.dart       # timeframes, shared by providers + chart
          instrument.dart         # Instrument, Quote, MarketRegion, session hours
          instrument_catalog.dart # bundled symbols, seeds search + watchlist
          market_data_provider.dart
          market_data_service.dart # routing, caching, request de-duplication
          broker_credentials.dart  # on-device Kotak credentials + session
          providers/               # binance / yahoo / kotak_neo
        services/
          progress_service.dart   # local: cleared levels, Discipline Points, streak
          purchases_service.dart  # RevenueCat wrapper
          crypto_api_service.dart # Binance client, shared by Pivot + Time Machine
      features/
        chart/                    # the shared pro chart — used by all three below
          pro_chart.dart
          model/                  # types, series aggregation, viewport, drawings
          painters/               # base layer + crosshair layer
          widgets/                # toolbar, indicator sheet, OHLC legend
          services/chart_preferences.dart
        live_market/
          live_market_home.dart   # watchlist
          instrument_detail_screen.dart
          broker_connect_screen.dart
          services/               # watchlist + polled quotes
        simulator/
          custom/                 # Custom Simulation: setup screen + level builder
          engine/
            replay_controller.dart
            decision_engine.dart      # Hold/Sell/Buy scoring — see ENGINE.md
            discipline_score.dart
            candle_model.dart
            script_event_model.dart
            endless_generator.dart    # random-window picker for Endless mode
          campaign/
            campaign_home.dart        # 15-level map
          endless/
            endless_home.dart
          level/
            level_screen.dart
            widgets/
              chart_view.dart
              decision_panel.dart     # Hold/Sell/Buy buttons at pause points
              blind_mode_overlay.dart # hides symbol/date until reveal
          debrief/
        daily_pivot/
          pivot_home.dart
          services/
            pivot_backend_service.dart  # Firestore read/write for vote + result
          widgets/
            question_card.dart
            sentiment_reveal.dart
        time_machine/
          calculator_screen.dart
          services/
            historical_price_lookup.dart  # live query, cached per session
          widgets/
            result_graphic.dart          # RepaintBoundary target for share export
        paywall/
        profile/
      data/
        simulator_levels/
          level_manifest.json
          <level_id>.json
          <level_id>_script.json
        simulator_endless/
          history_pool_<asset>.json      # 20-year bundled daily series per asset
    functions/                            # Firebase Cloud Functions (separate deploy)
      resolvePivot.js                     # scheduled 5pm job: query API, tally votes, write result

## Data flow — Behavioral Simulator (per level)

1. Load level (campaign) or generate a window (endless — see ENGINE.md §4).
2. `ReplayController` advances through candles at speed; asset name/date hidden per
   Blind Mode until debrief (see ENGINE.md §3).
3. At each scripted pause index, playback halts, screen does the flash/pause
   treatment, `decision_panel` presents Hold / Sell All / Buy the Dip.
4. `decision_engine` records the choice against that pause point's
   `optimal_action` field; continues playback.
5. At level end, `discipline_score.dart` computes the score, `debrief` reveals the
   real asset/dates/event and the score breakdown.

## Data flow — Daily Pivot

1. 9:00am local notification fires (scheduled client-side) → opens `pivot_home`.
2. `pivot_home` fetches today's question (pre-set once daily by the Cloud Function,
   or computed client-side from a fixed daily format — see DAILY_PIVOT.md) and the
   current vote tally from Firestore.
3. User votes once; write goes to Firestore; screen reveals updated crowd % and
   whether the user is with/against the majority.
4. At/after 5:00pm, `resolvePivot` Cloud Function queries the crypto API once,
   determines the outcome, writes it to Firestore.
5. Next app open (or a second scheduled local notification), `pivot_home` reads the
   resolved outcome, awards Discipline Points (with contrarian multiplier if
   applicable) via `progress_service`.

## Data flow — Time Machine

1. User enters an amount, a "what I bought instead" label, and a date (or picks a
   preset like the Royal Enfield example).
2. `historical_price_lookup` queries the crypto API for price-on-date and
   price-now, computes compounding, entirely client-side.
3. `result_graphic` renders the neon share card; `share_plus` hands it to
   Instagram/other targets. No account or gameplay state required to use this tab.

## Explicit non-goals for architecture
- No backend **of ours** for Simulator or Time Machine — resist adding one even if
  it would be "easier" for some feature; it isn't needed and adds review/deploy
  surface area this close to the deadline. Querying a third-party market API at
  runtime is not that, and is how Live Markets and the Custom Simulation work.
- No order placement, ever. Live Markets displays prices and the broker
  integration is read-only. The app must never be able to move real money.
- No user accounts/auth beyond RevenueCat's anonymous app-user-id and an anonymous
  Firebase identity for Pivot vote deduplication (one vote per user per day).
- No real-money mechanics in the Daily Pivot, ever — Discipline Points only.

## Data flow — Live Markets

1. `watchlistProvider` holds the user's instruments, persisted whole (not by id,
   since a searched symbol may not be in the bundled catalog).
2. `liveQuotesProvider` polls `MarketDataService` every 15s, and only while the
   app is foregrounded.
3. Tapping a row opens the instrument's chart. The chart asks the service for
   history at whichever interval the provider natively supports; anything
   coarser is folded client-side by `ChartSeries.aggregate`.

## Data flow — Custom Simulation

1. User picks an instrument, a date range and a timeframe.
2. `MarketDataService` fetches the window live.
3. `CustomSimBuilder` turns it into an ordinary `SimulationLevel`, deriving
   pause points with the same `PauseLadder` the campaign importer uses.
4. From there it is the standard Simulator flow — same engine, same scoring,
   same debrief. The only difference is `revealFromStart: true`, since the
   player chose the instrument and there is nothing for blind mode to hide.
