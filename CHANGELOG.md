# Changelog

Notable changes, newest first. Dates are the day the work landed on `main`.

## Unreleased — submission prep (2026-09-26)

### Fixed
- **A release build could have shipped Pro for free.** With no RevenueCat
  keys the app falls back to the unconnected store, and the paywall offered
  "continue without Pro" to everyone — all 15 Pro levels and the full Nerve
  Profile. The unlock is now refused in release builds whatever the store is
  doing, and `RC_TEST_KEY` is gated the same way.
- **Hindsight was scored as nerve.** 9 of 130 pause points are marked
  `ambiguous` in the level data, where price neither recovered nor fell
  further. Nothing read the flag, so selling there scored zero and counted
  as a panic. Those moments are now shown in the breakdown and left out of
  the score.

### Added
- **YOUR PATTERN** in the Debrief: how often you sold into a fall in earlier
  runs versus this one, and the average depth your earlier sells came at.
  Counted from stored runs; it needs two prior runs before claiming a trend.
- **About & disclaimer** screen, with Privacy, Terms, Manage subscription and
  the open-source licence page.
- Terms of Use and Privacy Policy links plus auto-renewal wording on the
  paywall.
- `PRIVACY.md` and `TERMS.md`, rendered into the web build by
  `tool/build_legal_pages.py`.
- `tool/validation/` — reproducible checks on every level and the Discipline
  Score, writing `docs/VALIDATION_REPORT.md`.
- Docs: `AUDIT_REPORT.md`, `docs/DATA_SOURCES.md`, `docs/QA_CHECKLIST.md`,
  `docs/DEMO_SCRIPT.md`, `docs/STORE_LISTING.md`.
- Tests for the Daily Pivot clock (IST boundaries, device timezone) and the
  release-build guard. 208 tests total.

### Changed
- Removed six unused packages: Firebase (core, Firestore, auth),
  `flutter_local_notifications`, `fl_chart`, `intl` and `cupertino_icons`.
  The web build no longer strips dependencies and the lockfile no longer
  needs reverting after `pub get`.
- The chart reads like a terminal: its own dark ground rather than the
  screen's alarm red, solid candles, gridline density that follows the pane,
  and a price scale that yields its row to the last-price tag.
- Campaign map matched to the reference design: tighter node pitch,
  alternating sides, coloured stars, white caps level names.

## 2026-09-17 — HistoX

### Changed
- Renamed from Market Nerve to HistoX: package, Android `applicationId`, iOS
  bundle ID (`com.histox.app`), launcher label, web title and every visible
  string.
- Brand colour moved from cyan to orange. Cyan kept for instrument readings
  (candles, live tape, crowd bar); green added for correct outcomes.

## 2026-09-15

### Added
- RevenueCat SDK powering the Pro subscription behind the existing
  `PurchasesService` seam.
- Mascot clips on the loading screens, onboarding and the web boot splash.

## 2026-09-11

### Added
- The September wireframe set across the app: campaign home, the level
  screen's four states, the accordion Debrief, the Daily Pivot client, the
  paywall and the Nerve Profile.
