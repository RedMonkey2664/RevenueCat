# Market Nerve

A behavioural finance simulator. You live through real market crashes, fast-forwarded,
and make the call at each pause point — hold, sell or buy the dip — then get graded on
discipline against what actually happened.

**No real money anywhere, ever.** The Simulator trades virtual capital. Live Markets
shows real prices and cannot place an order. The Daily Pivot pays in-app Discipline
Points only.

Built with Flutter for iOS and Android, for RevenueCat Shipaton 2026. A web preview
is deployed on Vercel: <https://revenue-cat-redmonkey2664s-projects.vercel.app>.

## What's in the app

| Pillar | What it does | Status |
|---|---|---|
| **Behavioural Simulator** | Campaign of historical crash replays with scripted pause points, a Debrief that scores your Discipline against the optimal move, and Endless mode over random historical windows. One engine; levels are data. | Built. 17 playable campaign levels (2 free, 15 Pro). Endless runs on the bundled crypto history pool. Custom Simulation replays any instrument, range and timeframe from live data. |
| **Daily Pivot** | One yes/no question a day: "Will BTC close above $X today?" Strike at 09:00 IST, resolved at 17:00 IST against Binance. | Client built. The crowd split is a **labelled local placeholder**. Not built: the Firestore backend, the two Cloud Functions, the 9:00/17:00 notifications. |
| **Time Machine** | "What if I had invested…" compounding calculator with a shareable result card. No login needed. | Built. |
| **Live Markets** | Watchlist of real prices across US equity, Indian equity and crypto, each opening a full interactive chart. Read only. | Built. Kotak Neo (real-time NSE/BSE) is present in outline but not finished. |

Around the pillars: onboarding, the Nerve Profile (with a share card), the Pro paywall,
and a shared pro chart (pan/zoom, crosshair, four chart types, six indicators, three
drawing tools) used by every screen that draws prices.

The UI follows the September 2026 wireframe set: a cyan tactical HUD theme with
bundled Inter and JetBrains Mono fonts.

## Getting started

Requires a Flutter stable release with Dart ≥ 3.11.1.

```sh
flutter pub get
flutter run
```

That runs the full app with the store disconnected (see below). To try purchases,
add RevenueCat keys first.

### Checks

```sh
flutter analyze
flutter test
```

`tool/screens/capture_test.dart` is a visual QA harness that renders screens to images.

## Pro and RevenueCat

Pro is sold through the RevenueCat SDK (`purchases_flutter`), behind one interface:
`PurchasesService` in [lib/core/services/purchases_service.dart](lib/core/services/purchases_service.dart).
Pro unlocks the Pro campaign levels (a PRO node on the map, or NEXT LEVEL into one) and
the Nerve Profile's full report.

- **With a key for the platform**, `RevenueCatPurchasesService`
  ([revenuecat_service.dart](lib/core/services/revenuecat_service.dart)) is configured
  at startup. The paywall shows the store's real prices from the current offering's
  Annual and Monthly packages; purchase and restore go through the SDK; Pro is the `pro`
  entitlement; renewals and expiries reach every gate as they happen.
- **Without a key** (the web preview, the tests, a fresh clone), the app runs on
  `StoreNotConnectedService`: no prices, no purchase, and a clearly labelled
  "PREVIEW BUILD · CONTINUE WITHOUT PRO" option that unlocks Pro for the session only.
  That option disappears on its own once a store is connected.

Keys are RevenueCat's public SDK keys, passed at build time and kept out of git:

```sh
cp config/revenuecat.example.json config/revenuecat.json   # then fill in the keys
flutter run --dart-define-from-file=config/revenuecat.json
```

| Key | Used on |
|---|---|
| `RC_APPLE_KEY` | iOS, macOS |
| `RC_GOOGLE_KEY` | Android |
| `RC_WEB_KEY` | Web (RevenueCat Web Billing) |
| `RC_TEST_KEY` | Every platform, overriding the others. Development only. Never ship it. |

The RevenueCat dashboard needs a `pro` entitlement, with the store products attached,
and a current offering holding an Annual and a Monthly package. Full setup is in
[MONETIZATION.md](MONETIZATION.md).

## Data

- **Campaign levels** are bundled JSON in `data/simulator_levels/`, one price file
  and one script file per level, indexed by `level_manifest.json`. Prices, dates and
  optimal actions are computed from real series by `tool/import_yahoo_level.dart` and
  `tool/import_binance_level.dart`. Nothing is typed by hand.
- **Endless** draws windows from `data/simulator_endless/`, built by
  `tool/build_history_pool.dart`.
- **Live data** is fetched at runtime, never bundled: Binance for crypto (real time),
  Yahoo for US and Indian equity (delayed). Every live number shows its source.

> **Licence status.** None of the bundled level data is cleared to ship in a published
> app yet. Every sourced level is marked `licence: unverified` in the manifest. Yahoo's
> terms forbid redistribution, and Binance's terms still need a read. The levels are
> fine for development and demos. See [LEVELS.md](LEVELS.md).

## Mascot

A black kitten with a pearl-and-sapphire tiara appears in loading states (the
`MascotLoader` and `runWithMascot` helpers in `lib/app/widgets/mascot.dart`), on the
first onboarding slide, and on the web boot splash, which stays up for at least 5
seconds.

Only the finished, keyed clips listed in `pubspec.yaml` are bundled: currently
`loading.mp4` and `welcome.mp4`. Raw exports in `assets/mascot/` are keyed onto the app
background by `tool/mascot/key_clip.py` before they ship. The planned clips, their
placements and their generation prompts are in [MASCOT.md](MASCOT.md).

## Web preview

The product ships on iOS and Android; the web build is a preview. Vercel has no Flutter
runtime, so the bundle is built locally and committed:

```sh
bash tool/publish_web.sh      # builds into web_dist/
git add web_dist && git commit -m "Update web preview" && git push
```

Pushing to `main` deploys via Vercel's Git integration.

What doesn't work in a browser:
- **US and Indian equity quotes:** Yahoo sends no CORS header.
- **File sharing and local notifications.**
- **Purchases,** unless a web key is set.

What does work: the Simulator, Time Machine, and the crypto side of Live Markets and
the Custom Simulation.

The script removes Firebase from the web build, because `firebase_core_web` doesn't
compile against this Dart SDK. `flutter pub get` adds the Firebase packages back into
`pubspec.lock`, so restore the committed lock (`git checkout -- pubspec.lock`) before
committing.

## Project layout

```
lib/
  app/            theme, router, phone frame, shared HUD widgets, mascot
  core/           market data providers, indicators, services (progress, purchases)
  features/
    simulator/    engine, campaign, level, debrief, endless, custom simulation
    daily_pivot/  pivot client, scoring, placeholder backend
    time_machine/ calculator and share card
    live_market/  watchlist and instrument detail
    chart/        the shared pro chart
    onboarding/  paywall/  profile/
data/             bundled campaign levels and Endless pools
tool/             data importers, web publish script, mascot keying, screen capture
test/             unit and widget tests
```

## Docs

| File | Covers |
|---|---|
| [CLAUDE.md](CLAUDE.md) | Product scope, the stack, non-negotiables |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Code structure and backend design |
| [ENGINE.md](ENGINE.md) | The Simulator engine and scoring |
| [LEVELS.md](LEVELS.md) | Campaign levels, sourcing and licensing |
| [DAILY_PIVOT.md](DAILY_PIVOT.md) | Daily Pivot rules and what's built |
| [TIME_MACHINE.md](TIME_MACHINE.md) | Time Machine spec |
| [DESIGN.md](DESIGN.md) | Visual system and labelling rules |
| [MONETIZATION.md](MONETIZATION.md) | Pro tier and RevenueCat setup |
| [MASCOT.md](MASCOT.md) | Mascot pipeline and clip prompts |
| [ROADMAP.md](ROADMAP.md) | Build phases and the cut list |

## Before store submission

Still open (see [ROADMAP.md](ROADMAP.md), Phase 8):
- RevenueCat dashboard setup and public keys; a sandbox purchase test on both platforms.
- Terms of Use and Privacy Policy pages, linked from the paywall.
- Release signing for Android (release builds currently use the debug key), the launcher
  label (currently `market_nerve`), and an app icon to replace the default Flutter one.
- Store screenshots and the demo video.
- The Daily Pivot backend and notifications.
- Clearing data licences for the bundled levels.
