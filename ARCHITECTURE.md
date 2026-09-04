# ARCHITECTURE.md

## High-level shape

    ┌───────────────────────────────────────────────────────────┐
    │                        App Shell (3 tabs)                  │
    │   Simulator (Campaign/Endless) | Daily Pivot | Time Machine │
    └───────┬──────────────────────┬───────────────────┬────────┘
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

Only the Daily Pivot touches a backend. Simulator and Time Machine are fully
client-side (bundled data / live public API respectively) — keep it that way; don't
let backend dependency creep into the other two pillars.

## Folder structure

    lib/
      main.dart
      app/
        router.dart              # 3-tab shell
        theme.dart                # DESIGN.md tokens
      core/
        services/
          progress_service.dart   # local: cleared levels, Discipline Points, streak
          purchases_service.dart  # RevenueCat wrapper
          crypto_api_service.dart # CoinGecko/Binance client, shared by Pivot + Time Machine
      features/
        simulator/
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
- No backend for Simulator or Time Machine — resist adding one even if it would be
  "easier" for some feature; it isn't needed and adds review/deploy surface area
  this close to the deadline.
- No user accounts/auth beyond RevenueCat's anonymous app-user-id and an anonymous
  Firebase identity for Pivot vote deduplication (one vote per user per day).
- No real-money mechanics in the Daily Pivot, ever — Discipline Points only.
