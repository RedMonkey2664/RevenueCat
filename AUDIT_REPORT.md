# HistoX — submission audit

Branch: `submission-prep`. Every finding below was checked against the code
or the data, not assumed. Numbers come from `tool/validation/run_all.sh`,
which regenerates [docs/VALIDATION_REPORT.md](docs/VALIDATION_REPORT.md)
from the files the app ships.

**This audit is partial.** Phases 0, 1 (security and purchases) and 2
(level and scoring validation) are done. What has not been done is listed
under "Not yet audited" so nobody mistakes silence for a pass.

## Baseline

| Check | Result |
|---|---|
| `flutter analyze` | no issues |
| `flutter test` | 196 passing before this audit, 198 after |
| Secrets in git history | none — `git log -S"appl_"` and `-S"goog_"` match only the placeholders in `config/revenuecat.example.json` |
| `config/revenuecat.json` | gitignored (`.gitignore:48`) |

README claims verified against code: 17 playable levels (2 free, 15 Pro) in
`level_manifest.json`; 6 indicators and 4 chart types in
`chart_types.dart:130,14`; 3 drawing tools (`ChartTool` minus `cursor`);
5 Nerve Profile axes (`NerveTrait`). All correct.

## Findings

### A-1 · BLOCKER · fixed
**A release build could give every user Pro for free.**
`lib/features/paywall/paywall_screen.dart`, `lib/core/services/purchases_service.dart`

A release build shipped without RevenueCat keys falls back to
`StoreNotConnectedService`, and the paywall then offered "PREVIEW BUILD ·
CONTINUE WITHOUT PRO" — unlocking all 15 Pro levels and the full Nerve
Profile. Nothing checked the build mode; the only guard was "is a store
connected", which is exactly false in that build.

**Fixed:** `kPreviewUnlockAllowed = !kReleaseMode`. `unlockPreview()`
refuses in release whatever the store is doing, and the button is only
offered when the unlock could be granted. **Verified:** new test in
`test/paywall/pro_access_test.dart` locks the constant's definition; 198
tests pass.

### A-2 · MAJOR · fixed
**`RC_TEST_KEY` worked in a release build.**
`lib/core/services/revenuecat_service.dart:34`

The Test Store key took priority over every platform key with no build
check, so a release build made with it would have run against a store
where no purchase is real. **Fixed:** ignored when `kReleaseMode`.

### A-3 · MAJOR · fixed (previous session, listed for completeness)
**Hindsight was scored as nerve.** 9 of 130 pause points carry
`derived.ambiguous` and nothing read the flag, so selling at a moment the
importer itself calls unanswerable scored 0 and counted as a panic. Now
parsed, reported in the breakdown, excluded from the score.

### A-4 · MAJOR · needs owner decision
**Five levels give a perfect score for tapping Hold four times.**

On `taper_tantrum_2013`, `china_selloff_2015`, `svb_2023`,
`yuan_devaluation_2015` and `demonetisation_2016`, every graded pause point's
optimal move is `hold`, so "always Hold" scores **100/100** without the
player reading anything.

Across the campaign: always Hold averages **72**, always Buy the Dip **66**,
always Sell **21**, random play **53**. The score is not reducible to one
button overall, and random landing mid-table is the right shape — but those
five levels cannot tell a disciplined player from an inattentive one.

**Recommendation:** these are the shallow, fast-recovery events, so "hold"
genuinely is right at every point — the data is not wrong. Either add one
deeper pause point to each (where the data supports a sell), or accept them
as the campaign's easy tier and stop counting a level as "cleared" at 100
when a single repeated action achieves it. Do not reweight the score to
manufacture difficulty.

### A-5 · INFORMATIONAL · no action
**No survivorship bias.** The worry that all 17 levels are V-shaped
recoveries is not borne out: **10 of 17 never regain their pre-crash peak
inside the played window**, and stored optimal moves are near-balanced
(hold 47, buy the dip 42, sell 41). The campaign does not teach "buy every
dip".

### A-6 · INFORMATIONAL · no action
**61 of 130 optimal moves differ from an independently recomputed rule** —
but this is a difference of definition, not a data error. My rule asks
"±5% within 20 trading days"; the shipped rule asks whether price recovered
or fell further over the remaining window. The shipped rule is the more
conservative of the two (it yields 47 holds where mine yields 17) and is the
better fit for the product. Both are printed in the validation report so the
difference is auditable.

### A-7 · INFORMATIONAL · no action
**Level data is clean and matches the events claimed.** Zero ordering,
duplicate, OHLC or volume problems across all 17 levels. Spot-checked
against known history: Dot-com peak 2000-03-10, GFC peak 2007-10-09 and
trough 2009-03-09, crypto winter −83%. All correct.

### A-8 · MAJOR · fixed
**Six unused packages were shipping**, including Firebase and
`flutter_local_notifications`. Nothing in `lib/`, `test/` or `tool/`
imported them. Firebase was also why the web build had to strip
dependencies from `pubspec.yaml` and why the lockfile had to be reverted
after every `pub get`. Removed; `publish_web.sh` is now just a build.

### A-9 · MAJOR · fixed
**A subscription paywall with no Terms or Privacy links** would fail App
Store review. Added, with auto-renewal wording, plus an About and
disclaimer screen and a Manage-subscription link. `PRIVACY.md` and
`TERMS.md` are the source and render into the web build, so the links and
the repository cannot drift.

### A-10 · INFORMATIONAL · verified correct
**The Daily Pivot clock.** Audited because a half-hour slip would pick a
different Binance bar and could flip Yes to No silently. It is right: IST
is a constant +5:30 with no daylight saving, 09:00 IST resolves to 03:30
UTC and 17:00 IST to 11:30 UTC, resolution reads the 16:59 close, and every
conversion goes through `toUtc()` so the device's timezone cannot move the
day. Ten tests now hold it.

### A-11 · MINOR · noted, not changed
**The repo is not `dart format` clean** — 68 files predate it. Reformatting
before submission would bury the real diffs, so CI runs analyze, test and
validation but no format gate. Worth doing once the store work lands.

## Not yet audited

Listed honestly rather than left silent. None is known to be broken; none
has been checked in this pass.

- Simulator engine edge cases (1.1): speed-vs-pause-point races, zero-cash
  buys, selling with no position, hot restart mid-run.
- Blind-play leak hunt (1.2) beyond what the capture screenshots show.
- Chart engine (1.3): indicator maths against reference implementations,
  degenerate series (1 candle, flat prices, NaN), `shouldRepaint`.
- Daily Pivot: vote sealing across clock changes, and the strike fairness
  simulation (2.8). The clock itself is now verified — see A-10.
- Time Machine maths (1.5, 2.7) against high-precision recomputation.
- Live Markets (1.6): Yahoo 401/429/schema changes, currency mixing.
- Persistence schema versioning and corrupt-JSON startup (1.8).
- Accessibility (1.10): text scaling, small screens, tap targets.
- Endless and Custom Simulation validation (2.5, 2.6).
- Nerve Profile axis correlation (2.4).
- Store submission mechanics that need accounts or a Mac: sandbox purchase
  runs (scripted in `docs/QA_CHECKLIST.md`), `flutter build ios`, icons,
  screenshots, release signing.

## Needs owner decision

1. **A-4** — the five levels where Hold scores 100.
2. **Bundled data licensing** — unchanged from the README's own warning:
   Yahoo's terms forbid redistribution and every level is marked
   `licence: unverified`. This blocks publishing, not building.
3. **Ambiguous pause points** — 9 are now excluded from scoring. If you would
   rather they were graded leniently than skipped, say so.

## Final gate

| Command | Result |
|---|---|
| `flutter analyze` | no issues |
| `flutter test` | 208 passing |
| `bash tool/validation/run_all.sh` | 17 levels, 0 data problems; report byte-identical to the committed one |
| `bash tool/publish_web.sh` | builds, 24 MB, includes `/privacy.html` and `/terms.html` |
| `flutter build apk --release` | **not run** — no Android SDK in this environment |
| `flutter build ios` | **not run** — needs a Mac |

## Tally

| | Count |
|---|---|
| Findings recorded | 11 |
| Blockers fixed | 1 |
| Majors fixed | 5 |
| Minors noted | 1 |
| Verified correct, no change | 3 |
| Needs owner decision | 4 |

### Needs owner decision, most important first

1. **Bundled data licensing** — blocks publishing. Options in
   `docs/DATA_SOURCES.md`; recommendation is to re-import the equity levels
   from a redistributable source.
2. **App icon** — still Flutter's default, which is third-party branding
   Apple will reject.
3. **Android release signing** — still the debug key.
4. **A-4, the five levels where always-Hold scores 100.**

## Deliverables

`AUDIT_REPORT.md` (this file) · `docs/VALIDATION_REPORT.md` ·
`tool/validation/` · `docs/DATA_SOURCES.md` · `docs/QA_CHECKLIST.md` ·
`docs/DEMO_SCRIPT.md` · `docs/STORE_LISTING.md` · `PRIVACY.md` ·
`TERMS.md` · `CHANGELOG.md` · `.github/workflows/ci.yml` · updated
`README.md`.

Not produced: `docs/SCORING.md` (the formula is documented in
`discipline_score.dart` and measured in the validation report) and the
re-fetch validator (needs network and settled provider terms).
