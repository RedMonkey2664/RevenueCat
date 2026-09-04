# TIME_MACHINE.md — The Growth Loop

Purpose: pure top-of-funnel virality. No login, no gameplay state, no dependency on
having played the Simulator — someone should be able to open this tab as a first
app action from a shared Instagram story and get value in seconds.

## The calculator
Inputs:
- Amount (₹) — free text or a slider with sensible presets.
- "What I bought instead" — free text label (e.g. "Royal Enfield"), purely cosmetic
  for the output copy, not used in any calculation.
- Date — date picker, reasonably bounded to whatever range the price-lookup source
  actually covers (don't let users pick a date before the asset existed).
- Asset to compare against — MVP: BTC only (matches Daily Pivot's asset, reuses the
  same `crypto_api_service`). A short curated preset list (BTC, ETH, maybe a major
  index) is a reasonable stretch add if time allows — not required for launch.

Computation (client-side, using `historical_price_lookup`):
1. Fetch asset price on the chosen date and current price (live query, cached for
   the session — don't re-query on every keystroke).
2. `missed_value = amount * (price_now / price_on_date)`
3. Output: `missed_value - amount` framed as "what it cost you," alongside the raw
   multiple ("your ₹80,000 would be worth ₹X today — a Yx return").

This is straightforward compounding-through-price-ratio math, not a compound-
interest formula — the "growth" is whatever the asset actually did between the two
dates, not an assumed annual rate. Keep the computation and its assumptions visible
in a small "how we calculated this" disclosure — this is a persuasive/emotional tool
and should stay honest about being illustrative, not projected/guaranteed.

## The output — share graphic
- Rendered client-side: a `result_graphic` widget wrapped in `RepaintBoundary`,
  captured as an image, shared via `share_plus`.
- Visual: dark/neon treatment consistent with DESIGN.md's overall aesthetic, large
  headline number, the "instead of X" framing, small app branding/watermark and a
  short CTA (e.g. "Test your own regret →") baked into the image itself — the image
  is the marketing unit, so the watermark is not optional.
- Keep the shareable card to a single, fixed aspect ratio sized for Instagram
  Stories (9:16) for MVP — don't build multiple export formats.

## Copy/tone guardrails
- Frame as illustrative and retrospective ("here's what happened," not "here's what
  will happen if you invest now") — this is a behavioral/educational hook, not
  investment solicitation, and that distinction matters for both honesty and store-
  review risk given the app's finance-adjacent category.
- Never imply guaranteed future returns anywhere in this tab's copy.

## Explicit non-goals for MVP
- No saved history of past calculations, no comparison against multiple assets in
  one card, no server-side image rendering, no direct in-app posting API (share
  sheet only — let the OS/Instagram handle the actual post).
