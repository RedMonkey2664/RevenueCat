# MASCOT.md — The Nerve cat: clips, placement, and Google Flow prompts

The mascot is a small black cat with bright blue eyes, a silver-and-pearl
tiara set with sapphire teardrops, and a matching pearl-and-sapphire
necklace (reference: the full-body illustration Somi supplied, Sep 2026).
It is the face of the *behavioural* side of the app — it appears wherever the
app talks about you, and never where it would nudge a decision.

## Where the mascot never goes
- **The halted decision panel (artboard 1c).** A cat reacting to a falling
  tape is a nudge — the panel must not editorialise (ENGINE.md §2).
- **Inside a single loading value.** Rows keep the hatch-and-pulse of the
  feed-state grammar (DESIGN.md); the mascot is for waits on real work.
- **Anything that looks like gambling.** No coins, dice, chips or cards near
  the Daily Pivot — it earns Discipline Points, never money (CLAUDE.md).

## Pipeline
1. Generate the clip in Google Flow with the prompt below. Use **Ingredients
   to Video** with the reference illustration so the character stays on
   model, 9:16 vertical, 8 seconds.
2. Drop the export in `assets/mascot/`.
3. Key it onto the app's ground and name it for its use:
   `python tool/mascot/key_clip.py assets/mascot/<export>.mp4 <file_name>`
   (clips on the starfield instead of green skip this step).
4. Add the file to `pubspec.yaml` and a value to `MascotClip` in
   `lib/app/widgets/mascot.dart`, then place it.

Every prompt below shares the same **character line** and **production
line**; paste them in full each time — Flow does not remember a character
between generations.

**Character line**
> A small cute black kitten in clean 2D cartoon style with soft dark outlines,
> large bright sky-blue eyes, pink inner ears, a silver tiara of white pearls
> with blue sapphire teardrop gems, and a matching pearl necklace with blue
> sapphire drops and a long pendant. Exactly as in the reference image.

**Production line**
> Solid flat chroma-key green background (#00B140), perfectly even, no
> gradient, no shadow on the background, no floor, no particles or glow
> spilling onto the green. Static locked-off camera, no zoom, no cuts. Full
> body in frame with space above the tiara. 9:16 vertical, 8 seconds. No
> text, no logos, no watermark. Silent, no music.

For a **looping** clip also add: *The last frame matches the first frame
exactly, so the clip loops seamlessly.*

## The clips

Status: ✅ in the app · 🔜 prompt ready, not generated yet.

### ✅ `loading` — every wait on real work
Plays on the web boot splash (full portrait) and as the in-app loader
(portrait for screen-level waits, head-in-a-disc for pane-level ones).
Already generated on a starfield; no keying needed.

### ✅ `welcome` — onboarding, first slide
The kitten walks in, sits and waves: the first thing a new player sees.
Generated as *Kitten sits and waves paw*, keyed with `key_clip.py`.

### 🔜 `debrief_iron_nerve` — Debrief, score 90+
> [Character line] The kitten sits perfectly still and composed, then slowly
> closes and opens its eyes in a calm, satisfied blink; the sapphires on its
> tiara catch a single soft sparkle. Serene, unshakeable, proud but not
> smug. [Production line]

### 🔜 `debrief_held` — Debrief, score 70–89 ("HELD YOUR NERVE")
> [Character line] The kitten sits upright, gives one small confident nod
> toward the camera and a gentle slow tail swish, then settles. Calm,
> steady, quietly pleased. [Production line]

### 🔜 `debrief_shaken` — Debrief, score 50–69
> [Character line] The kitten's ears flick back and its eyes widen as if
> startled by a sudden noise, it takes a small step back, then shakes its
> head, smooths its whiskers and sits back down, composing itself. Relatable,
> not comic. [Production line]

### 🔜 `debrief_panicked` — Debrief, score below 50
> [Character line] The kitten's fur puffs up and it hops straight up in
> surprise, lands, then looks at the camera a little sheepishly and sits
> down, tail curling around its paws. Gentle and forgiving — the moment says
> "it happens", never "you failed". [Production line]

### 🔜 `reveal` — the step from REVEAL & SCORE into the Debrief
> [Character line] The kitten stands beside a small dark velvet curtain,
> takes the edge in its paw and pulls it aside with a flourish, then turns to
> the camera expectantly. Theatrical, playful. [Production line]

### 🔜 `pivot_waiting` — Daily Pivot, vote sealed, before 17:00 (loop)
> [Character line] The kitten sits calmly watching something just off
> screen, its head tracking slowly left to right, tail swaying in a slow
> rhythm, one ear twitching now and then. Patient, attentive. [Production
> line] [Loop line]

### 🔜 `pivot_right` — Daily Pivot, "YOU WERE RIGHT"
> [Character line] A small glowing golden orb drifts down toward the kitten;
> it sits up, catches it gently between its front paws and holds it to its
> chest, eyes bright, tiara sparkling. Warm, earned — no confetti. [Production
> line]

### 🔜 `pivot_wrong` — Daily Pivot, "NOT THIS TIME"
> [Character line] A small glowing golden orb rolls slowly past the kitten
> and out of frame; the kitten watches it go, gives a small philosophical
> shrug of the shoulders, then sits and licks one paw, unbothered. The mood
> is "no penalty, try again tomorrow". [Production line]

### 🔜 `pivot_missed` — Daily Pivot, poll closed without a vote (loop)
> [Character line] The kitten is curled up asleep in a neat loaf, tiara
> slightly askew, breathing slowly, one ear twitching once. Cosy and quiet.
> [Production line] [Loop line]

### 🔜 `pivot_before_open` — Daily Pivot, before 09:00 IST
> [Character line] The kitten wakes up: it stretches its front legs forward
> in a long cat stretch, yawns widely, then sits up alert and bright-eyed,
> ready for the day. [Production line]

### 🔜 `streak_milestone` — the 7-day Pivot streak (×1.5 unlocked)
> [Character line] The kitten sits proudly as a soft ring of sapphire-blue
> light rises around it from the ground and fades, its tiara gems glowing
> brighter for a moment. Proud, celebratory, restrained. [Production line]

### 🔜 `profile_building` — Nerve Profile, fewer than 5 levels
> [Character line] The kitten is stacking three small glowing blue blocks
> one on top of another with careful paws, then steps back and tilts its
> head to look at the little tower, curious. Earnest, in progress.
> [Production line]

### 🔜 `profile_locked` — Nerve Profile, report ready but locked
> [Character line] A small silver padlock set with one blue sapphire sits
> beside the kitten; the kitten pats it curiously with one paw, looks at the
> camera, then pats it again. Inviting, not pleading. [Production line]

### 🔜 `profile_reveal` — Nerve Profile, first time the full report opens
> [Character line] The kitten sits in soft light, turns from profile to face
> the camera, lifts its chin and gives a slow confident blink, as if
> introducing itself. [Production line]

### 🔜 `paywall` — the Pro paywall
> [Character line] The kitten reaches up and adjusts its tiara with one paw
> so it sits perfectly straight, the gems give a single sparkle, then it
> looks at the camera with a small inviting head tilt. Elegant, premium,
> never pushy. [Production line]

### 🔜 `empty_watchlist` — Live Markets, nothing on the watchlist
> [Character line] The kitten peers into an empty open cardboard box, looks
> at the camera with a puzzled head tilt, then hops lightly into the box and
> sits in it. [Production line]

### 🔜 `feed_down` — full-pane feed failure
> [Character line] The kitten sits in front of a small unplugged cable lying
> on the ground, sniffs the plug, then nudges it with its nose and looks at
> the camera hopefully. Calm; the problem is fixable. [Production line]

### 🔜 `onboarding_pivot` — onboarding, slide 2 (the Daily Pivot)
> [Character line] Two small glowing arrows float beside the kitten, one
> pointing up in blue and one pointing down in red; the kitten looks from one
> to the other thoughtfully, then taps the up arrow with its paw. Thoughtful,
> decisive — a choice, not a bet. [Production line]

### 🔜 `onboarding_time_machine` — onboarding, slide 3 (Time Machine)
> [Character line] The kitten holds a small antique silver pocket watch in
> its front paws, the watch hands spin backwards with a soft blue glow, and
> the kitten looks up at the camera with wide, curious eyes. [Production
> line]
