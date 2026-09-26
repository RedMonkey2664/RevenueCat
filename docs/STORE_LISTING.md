# Store listing pack

Copy for App Store Connect and Google Play, plus the answers both consoles
ask for. Written to be accurate: nothing here claims the app predicts
markets or teaches investing skill, because it does neither.

## Names

- **App name:** HistoX
- **Subtitle (iOS, 30 chars):** Survive real market crashes
- **Short description (Play, 80 chars):** Replay real market crashes with virtual capital and see how you actually behave.
- **Bundle ID / applicationId:** `com.histox.app`
- **Category:** Education (primary), Finance (secondary)

## Long description

> Everyone thinks they would hold through a crash. HistoX lets you find out
> before it costs you anything.
>
> You are dropped into a real historical market fall — the 1987 crash, the
> dot-com collapse, 2008, COVID, a crypto winter — with virtual capital and
> no idea which one it is. The asset and the dates are hidden. The tape
> rolls, and at scripted moments it stops and asks one question: hold, sell,
> or buy the dip. There is no timer.
>
> Afterwards the Debrief shows what each call actually cost you, what price
> did next, and a Discipline Score that measures one thing — whether you cut
> a position while it was falling. Play a few runs and it starts comparing
> them: how often you sold into a fall before, how often this time, and how
> deep the fall usually was when you did.
>
> ALSO INSIDE
> · Daily Pivot — one call a day on Bitcoin, resolved against real prices
> · Time Machine — a what-if calculator with a shareable card
> · Live Markets — real prices across US, Indian and crypto markets,
>   read-only
> · Nerve Profile — a five-axis read of how you behave under pressure
>
> NO REAL MONEY, EVER
> HistoX is an educational simulator. Every position is virtual. The app
> cannot place a trade. Points have no cash value. The "historically optimal
> move" is a hindsight benchmark, worked out after the fact — it is not
> advice, and past performance does not predict future results.
>
> HistoX Pro unlocks fifteen more crashes and the full Nerve Profile.

## Keywords (iOS, 100 chars)

`crash,market,simulator,investing,behaviour,discipline,history,stocks,crypto,education,psychology`

## Age rating

- **Apple:** 4+. No gambling, no contests, no user-generated content, no
  unrestricted web access. Simulated gambling: **No** — there is no stake
  and no payout.
- **Google:** Everyone. Not a gambling app.

If asked whether the app is a financial product: **no**. It provides no
brokerage, no advice and no trading.

## Screenshot order (1179×2556, no device frame)

1. Pause point mid-crash, HALTED, decision buttons — the hook
2. Debrief with the Discipline Score
3. Campaign map with cleared nodes and stars
4. Daily Pivot question
5. Nerve Profile share card
6. Live Markets watchlist

## Apple privacy nutrition label

**Data not collected.** Nothing is linked to identity, nothing is used for
tracking.

The only third-party SDK is RevenueCat, which receives a randomly generated
anonymous app user ID and the purchase receipt. Declare under **Purchases →
Purchase History**, *not linked to identity*, used for **App Functionality**.

Answer **No** to tracking (no ATT prompt needed — no IDFA, no ad networks,
no analytics).

## Google Play Data safety

| Question | Answer |
|---|---|
| Does the app collect or share user data? | Yes — purchase history only, via RevenueCat |
| Personal info (name, email, address) | No |
| Financial info | Purchase history. Collected, not shared. Not linked to identity. App functionality |
| Location, contacts, photos, files, messages | No |
| Device or other IDs | No |
| Is data encrypted in transit? | Yes |
| Can users request deletion? | Yes — uninstalling deletes all local data; no account exists |
| Data used for advertising | No |

## Review notes (paste into both consoles)

> HistoX is an educational behavioural simulator. It does not place real
> trades, connect to a brokerage, or handle user funds. All positions use
> virtual capital. In-app "Discipline Points" have no monetary value and
> cannot be withdrawn or exchanged.
>
> The Daily Pivot is not gambling: there is no stake, no wager and no
> payout. A correct call earns in-app points only.
>
> Live Markets displays real, sometimes delayed, market prices for reference
> and is read-only.
>
> IN-APP PURCHASE: "HistoX Pro" is an auto-renewing subscription (monthly or
> yearly) unlocking 15 additional campaign levels and the full Nerve Profile
> report. Price, period and renewal terms are shown on the paywall, with
> Restore Purchases and links to Terms of Use and Privacy Policy.
>
> TO REVIEW THE PAYWALL: open the app, tap the Simulator tab, and tap any
> campaign node marked PRO. The paywall appears immediately; no progress is
> required.
>
> Privacy Policy: https://revenue-cat-redmonkey2664s-projects.vercel.app/privacy.html
> Terms of Use: https://revenue-cat-redmonkey2664s-projects.vercel.app/terms.html

## Subscription metadata

- **Group:** HistoX Pro
- **Display name:** HistoX Pro
- **Description:** Unlocks 15 more historical crashes and your full Nerve
  Profile report.
- Both durations must state price, period and renewal on the paywall, which
  they do.

## Still needed from the owner

- App icon (currently the default Flutter logo — Apple will reject this as
  third-party branding)
- Screenshots at 1179×2556
- Demo video (see DEMO_SCRIPT.md)
- Promo codes or a free trial for judges
- Android upload keystore (release currently signs with the debug key)
