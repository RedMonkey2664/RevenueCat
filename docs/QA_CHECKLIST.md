# QA checklist — run before submitting

Automated coverage is `flutter analyze`, `flutter test` (208 tests) and
`bash tool/validation/run_all.sh`. Everything below needs a human and a
real device, because it involves the stores, the clock or a network that
misbehaves.

Mark each: pass / fail / not run. Do not submit with an unexplained fail.

## 1. RevenueCat — the part judges will check

Needs sandbox accounts and the keys in `config/revenuecat.json`.

| # | Case | Expected |
|---|---|---|
| 1.1 | Fresh install, open paywall | Real prices from the store, in local currency. No "store not connected" |
| 1.2 | Buy monthly | Sheet completes, Pro unlocks immediately, a locked level opens |
| 1.3 | Buy yearly | Same, and the per-month figure matches the store's |
| 1.4 | Cancel the sheet mid-purchase | Sheet closes, no error toast, still not Pro |
| 1.5 | Restore on a second device, same store account | Pro returns without paying again |
| 1.6 | Restore with nothing to restore | "No Pro subscription to restore." |
| 1.7 | Airplane mode, open paywall | Readable message, no infinite spinner, no crash |
| 1.8 | Airplane mode, launch the app cold | App starts; store falls back quietly |
| 1.9 | Let a sandbox subscription expire | Pro content re-locks without a restart |
| 1.10 | Android deferred (pending) purchase | "Payment pending" message, Pro stays locked until it clears |
| 1.11 | Buy, then request a refund | Entitlement drops on the next customer-info update |
| 1.12 | Upgrade monthly to yearly | No double charge; entitlement continuous |
| 1.13 | Offering missing or misconfigured | Paywall says the plan is unavailable; no crash |
| 1.14 | Terms, Privacy and Manage subscription links | All three open in a browser |

## 2. The release-build guard

| # | Case | Expected |
|---|---|---|
| 2.1 | `flutter build apk --release` with **no** keys, install, open paywall | **No** "CONTINUE WITHOUT PRO" button. Pro stays locked |
| 2.2 | Same build, try to open a Pro level | Paywall appears and cannot be bypassed |
| 2.3 | Debug build, no keys | Preview button present (intended) |

2.1 is the blocker fixed in this branch. Verify it by hand before shipping.

## 3. Simulator

| # | Case | Expected |
|---|---|---|
| 3.1 | Play a level at 1x, 2x, 4x | Every pause point fires exactly once; none skipped at 4x |
| 3.2 | Hold, Sell All and Buy the Dip at a pause point | Cash and position update correctly; Debrief P&L matches |
| 3.3 | Background the app mid-run, return | Run intact, no double-advance |
| 3.4 | Kill the app mid-run, reopen | No corrupt progress; level replayable |
| 3.5 | Finish the same level twice | Best score kept; run history has two entries |
| 3.6 | Rotate the device mid-run | No overflow, no state loss |
| 3.7 | Play a level with no decisions reached | Score shows "not tested", not 0 or 100 |

## 4. Daily Pivot

The clock is covered by tests; these need a real day.

| # | Case | Expected |
|---|---|---|
| 4.1 | Open before 09:00 IST | Pre-open state, no strike yet |
| 4.2 | Vote, then force-quit and reopen | Vote sealed, unchanged |
| 4.3 | Change the device timezone after voting | Same day, same vote, same strike |
| 4.4 | Wait past 17:00 IST | Resolves against the 16:59 IST close |
| 4.5 | Miss a day, come back | Streak resets without crashing |
| 4.6 | Airplane mode | Readable unavailable state, not a spinner |

## 5. Live Markets and Time Machine

| # | Case | Expected |
|---|---|---|
| 5.1 | Watchlist with US, Indian and crypto rows | Correct currency symbol each; delayed rows say so |
| 5.2 | Yahoo returns 429 or empty | Row shows "feed unavailable" with retry |
| 5.3 | Time Machine with a date before the asset existed | Refuses with a reason; does not guess |
| 5.4 | Share a Time Machine card | Share sheet opens; cancelling it does not crash |

## 6. Accessibility and layout

| # | Case | Expected |
|---|---|---|
| 6.1 | Text size 1.3x and 2.0x | No overflow on the pause point, Debrief or paywall |
| 6.2 | 360x640 screen | Hold / Sell All / Buy the Dip all reachable |
| 6.3 | Tap targets | All three decision buttons at least 44pt tall |
| 6.4 | P&L colours | Sign or arrow present, not colour alone |
| 6.5 | Screen reader on the pause point | Buttons announce their action |

## 7. Store metadata

| # | Case | Expected |
|---|---|---|
| 7.1 | App label on the home screen | "HistoX" |
| 7.2 | Icon | HistoX icon, **not** the default Flutter logo |
| 7.3 | Bundle IDs | `com.histox.app` on both platforms |
| 7.4 | Android release signing | Upload key, not the debug key |
| 7.5 | iOS Info.plist | No unused usage-description strings |
