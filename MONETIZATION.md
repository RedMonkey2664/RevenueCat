# MONETIZATION.md — RevenueCat Structure

## Model
Single auto-renewing subscription ("Pro"), no consumables, no ads — same simple
model as before, now spanning three pillars so the paywall pitch needs to summarize
value across all of them without feeling scattered.

## Free tier
- Simulator: first 3-4 campaign levels (recommend: 1987 Black Monday, 2018 Crypto
  Winter, 2010 Flash Crash — the "beginner" tier from LEVELS.md) fully playable with
  the full real engine (blind mode, decision mechanic, Discipline Score) — free
  users get the actual product, not a crippled demo.
- Daily Pivot: fully free, unlimited — it's a retention/growth tool, gating it
  defeats its purpose.
- Time Machine: fully free, unlimited, no login required — it's the growth loop,
  gating it defeats its purpose even more directly than gating Pivot would.

## Pro tier unlocks
- Remaining campaign levels (the intermediate/advanced tiers from LEVELS.md).
- Endless mode (positioned as a Pro-only "infinite" feature — natural gate, since
  it's explicitly framed as unlocking "once handcrafted levels are beaten," so
  gating it behind Pro rather than behind completion is a reasonable product choice
  worth flagging to Somi as a decision, not silently assuming).
- The Simulator's dummy/locked chart chrome (extra indicators, chart types, etc.)
  does not need to become real for the hackathon demo, but paywall copy should
  describe it honestly as "more tools coming" rather than implying it's fully built.

## RevenueCat integration checklist
1. Configure the app in the RevenueCat dashboard; one subscription product
   (monthly, optionally an annual discount) and one Entitlement (`pro`).
2. `purchases_service.dart`: `configure()`, `getOfferings()`, `purchasePackage()`,
   `restorePurchases()`, `checkEntitlement('pro')`.
3. Gate checks happen in exactly two places: the campaign level loader (before
   loading a `locked: true` level) and the Endless mode entry point. Daily Pivot and
   Time Machine never call the entitlement check.
4. Use RevenueCat's standard paywall presentation rather than hand-building a custom
   purchase UI — minimizes integration risk this close to the deadline.
5. Restore Purchases reachable from Paywall and Profile — App Store review checks
   for this explicitly.
6. Sandbox-test purchases on both platforms in ROADMAP.md's dedicated phase, not the
   night before submission.

## What NOT to build for MVP
- No tiered pricing (single Pro tier).
- No per-level one-time purchases.
- No monetization inside Daily Pivot or Time Machine (no ads, no "pay to skip",
  nothing) — both stay pure free funnels into the Simulator, per the original brief.
- No hand-rolled trial logic beyond what RevenueCat/the store provides natively.
