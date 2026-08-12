# DOODLE JUMP CLASSIC (2009–2010) — AUTHORITATIVE IMPLEMENTATION SPEC
**Target:** faithful, original-code recreation as a modern iOS SpriteKit game.
**Coordinate frame:** all numbers in this spec are in **logical points at 320×480 portrait** (the original iPhone playfield). Implement the SKScene at 320×480 logical size and scale up (`.aspectFill` with the 320-pt width pinned; extra vertical space on tall phones extends the visible playfield upward/downward symmetrically, HUD pinned to safe area). Score units = points of altitude (1 score ≈ 1 pt of climb; 1 screen ≈ 480 score).

Confidence markers: **[C]** corroborated by ≥2 reports, **[E]** estimate from clone/measurement analyses, **[DEFAULT]** value proposed here where sources are silent, **[CONFLICT]** sources disagree (chosen value noted).

---

## 1. FEATURE SET (classic era only, v1.0 Mar 2009 → v1.27 Dec 2010)

### IN SCOPE (core recreation — original "notebook" theme)
| Feature | Introduced | Rationale |
|---|---|---|
| Auto-bounce jumping, tilt-to-steer, horizontal screen wrap | 1.0 | Core loop |
| Tap-to-shoot pellets; directional aiming with Options toggle (off = straight up) | 1.0 / 1.1 | Both modes existed in classic era; toggle added 1.2 |
| Platforms: green (static), blue (horiz. mover), brown (broken), white (one-shot), gray-blue (vert. mover), yellow→red (exploding), dark-blue 4-arrow (draggable/movable) | 1.0–1.6 | All classic; all corroborated |
| Power-ups: spring, trampoline, propeller hat, jetpack, spring shoes, force shield | 1.0–1.12 | All classic |
| Monsters (9-type roster incl. 5-shot boss), stomp-to-kill, audio proximity warning | 1.0–1.9 | Classic bestiary |
| UFO with abduction beam; shootable; stompable; double/triple formations | 1.0 / 1.13.3 / 1.15 | Classic |
| Black hole (indestructible suction hazard) | 1.0 | Classic |
| Set-pieces: monster roadblocks, forced stomp routes, spring ladder (~40k), triple-UFO | 1.7–1.15 | "Sticky situations" are part of the classic feel |
| Progressive difficulty by altitude; guaranteed-solvable generation | 1.0 / 1.7 | Core |
| In-world altitude **score markers** (personal best + local top scores + recent scores, name-labeled) | 1.0 / 1.2 | The game's signature social hook; implement with local scores + Game Center friends where available |
| HUD: torn-paper top strip, score top-left, pause top-right, **max 5 pauses/game** | 1.1 | Documented fairness rule |
| Main menu with idle bouncing Doodler; Play / Scores / Options / Resume | 1.0 | Documented |
| Game over panel with name entry, play again / menu; local top-10 leaderboard | 1.0 | Documented |
| Stats screen: games played, high score, average score, total jumps, jetpack flights, propeller flights, UFOs shot; resettable | 1.12–1.15 | Documented |
| Options: sound on/off, directional-shooting toggle, tilt calibration | 1.2 / 1.3.1 | Documented |
| First-run "how to play" hints; one-time hint on first movable platform ("you can drag these platforms around with your finger") | 1.3 / 1.6 | Documented |
| SFX-only audio (no music); allow user's own music to keep playing | 1.1 | Documented — audio session category `.ambient` |
| Game Center leaderboard + achievements (arrived Nov–Dec 2010, inside window) | 1.25/1.26 | Modern replacement for the dead Lima Sky server |

### OUT OF SCOPE (with rationale)
- **All alternate themes** (Ghost/Halloween, Winter, Jungle, Space, Easter, Soccer, Underwater, Doodlestein) — classic-era but each is a full reskin + bestiary; cut for scope. Architecture should keep sprites/sounds behind a theme table so these are addable later. Name-code easter eggs ("Boo", "Snow", "Ooga", "Bunny", "Creeps") — stretch goal only.
- **Rocket power-up** — classic era (1.18, Apr 2010) but debuted in and stayed characteristic of the Space theme; not part of the notebook theme. Constants included below for completeness; do not spawn it. [CONFLICT-adjacent: Report 3 calls it "post-classic" for the notebook theme; Reports 1–2 date it Apr 2010.]
- **Shifting platforms and holographic/appearing platforms** — [CONFLICT] Report 1 dates both to v2.6 (Sep 2011, post-classic); Report 3 claims a holographic platform existed from v1.7 (2009). Report 1's explicit version-note sourcing is stronger. **Excluded.** (See open questions.)
- **Multiplayer race mode (2.0), coins/store/outfits (3.0+), missions, tournaments, Ice Blizzard theme, ads** — all post-2010.
- **Lima Sky global server leaderboard, Facebook boards, tweet-score** — dead/obsolete services; Game Center substitutes.
- **Pocket God / The Creeps crossovers** — licensed content.
- **Pickle costume (500 losses), boss variants beyond one boss type** — stretch goals.

---

## 2. PHYSICS CONSTANTS TABLE

Integrate per-frame: `vy -= G*dt; y += vy*dt` (custom integration; do **not** use SpriteKit physics engine — collisions are simple AABB/segment tests). Horizontal and vertical motion fully independent [C].

| Constant | Value | Notes |
|---|---|---|
| Playfield | 320 × 480 pt, portrait only | [C] |
| Gravity `G` | **650 pt/s²** | [E] Derived so apex/airtime match measurements; tunable envelope 650–1250 with v0 scaled to keep apex ≈150 |
| Jump takeoff velocity `V_JUMP` | **440 pt/s** | [E] Apex = V²/2G ≈ **149 pt** (~31% screen), full parabola ≈ **1.35 s** — matches Vernier video measurement (2.3 m at g=10). [CONFLICT: Report 3 estimated apex ~190 pt from footage; 150 pt is corroborated by two independent clone analyses + the physical measurement chain → chose 150] |
| Terminal fall velocity | none (uncapped) | [E] No source reports a cap; optional safety clamp 900 pt/s [DEFAULT] |
| Doodler collider | feet segment: width ≈ 30 pt, at sprite bottom | [E] Land anywhere across platform width; feet-only, one-way (test only when `vy < 0`) [C] |
| Doodler sprite size | ≈ 40 w × 45 h pt | [DEFAULT] |
| **Tilt mapping** | `vx = clamp(ax_g × 400, −300, +300)` pt/s, where `ax_g` = calibrated accelerometer X in g | [E/DEFAULT] Velocity-style, proportional, near-raw. Light low-pass: `vx_smooth += (vx − vx_smooth) × min(1, dt/0.05)`. No inertia when leveled (stops within ~0.1 s). Community gain converges ~200–400 pt/s per g; full tilt crosses screen in ~1.1 s |
| Tilt calibration | store offset `ax0` on demand from Options; use `ax_g − ax0` | [C] |
| Update rate | 60 Hz accelerometer + render | [DEFAULT] |
| **Screen wrap** | when Doodler center x < 0 → x += 320; x > 320 → x −= 320. Draw a duplicate sprite on the opposite edge while straddling so it visibly slides off/on | [C/E] Doodler only; platforms, items, monsters, projectiles never wrap |
| **Spring boost** | instant `vy = 677 pt/s` → rise **352 pt** | [C: 352 from wiki measured table] |
| **Trampoline boost** | instant `vy = 822 pt/s` → rise **520 pt** | [CONFLICT: 520 (measured table, Reports 1&3) vs ~700 (Report 2) → chose **520**] Doodler backflips during flight; cannot shoot mid-flip |
| **Spring shoes** | **6 bounces** at `vy = 670 pt/s` (≈345 pt each, ≈2,068 total), then shoes detach and tumble away | [CONFLICT: 6×345 (Report 3, measured) vs ~5×500 (Report 2) → chose 6×345] Can shoot and stomp while worn |
| **Propeller hat** | sustained ascent: accelerate at 1,500 pt/s² up to cruise **450 pt/s**, hold; total duration **4.0 s**, total gain ≈ **1,736 pt** | [C gain: 1,736; duration/speed E] Steerable; cannot shoot; kills monsters on contact; hat detaches and falls at expiry, Doodler falls into normal bounce |
| **Jetpack** | 3 phases: ignition 0.5 s (0→800 pt/s), cruise 3.2 s @ 800 pt/s, burnout 0.8 s (800→440 pt/s); total ≈ **4.5 s**, gain ≈ **3,307 pt** | [C gain: 3,307; profile E] Steerable; cannot shoot; detaches and tumbles at burnout |
| **Rocket** (not spawned — see §1) | ≈ 4 s, gain ≈ **6,521 pt**, peak ~1,900 pt/s | [C gain] |
| **Shield** | duration **8 s** [DEFAULT]; blocks monster contact only — NOT black holes, NOT UFO abduction, NOT falling | [C] Blink during final 2 s [DEFAULT] |
| Powered-flight invulnerability | while jetpack or propeller hat is active: immune to monsters and UFO beam; black holes still lethal | [CONFLICT: Report 1 says invincible to passed hazards; Report 2 says uncertain, suggests hat=vulnerable → chose immune for both, since propeller "shreds monsters on contact" is documented; black hole always wins] |
| **Projectile ("nose ball")** | speed **1,000 pt/s** [E 800–1,200], straight line, no gravity, no wrap, despawns off-screen; radius 4 pt [DEFAULT]; one per tap, rate limited only by tapping (hard cap 10/s [DEFAULT]) | [C behavior, E speed] Directional mode: angle = vector from Doodler to tap point, clamped to within ±70° of vertical [DEFAULT]; non-directional: straight up. Passes through platforms; collides with monsters/UFOs only |
| Stomp rebound | landing on monster/UFO top = normal bounce `vy = V_JUMP` | [C] |
| Camera threshold | Doodler above y = **240** (screen midpoint) → scroll world down by surplus; camera never scrolls down | [C] |
| Black hole radii | kill (capture) radius **≈ 55 pt** from center to Doodler center; suction pull begins at **80 pt**, force pulls Doodler toward center at up to 250 pt/s² [DEFAULT] | visual Ø ≈ 100 pt (~1/3 screen) [O] |
| UFO beam | cone under UFO, width ≈ 60 pt at Doodler height [DEFAULT]; entering beam or touching hull sides = abduction |
| Platform sprite | **57 × 15 pt** | [C/O] |
| Blue platform speed | `40 + 60 × min(score/50000, 1)` pt/s, ping-pong, reverses at screen edges (no wrap) | [C behavior, E numbers] |
| Gray platform motion | vertical oscillation, amplitude 40–80 pt, speed `30 + 50 × min(score/50000,1)` pt/s | [E/DEFAULT] |
| Exploding platform timer | turns red **1.5 s** after entering view, detonates **1.5 s** later [DEFAULT]; explodes whether or not stood on | [C behavior] |

---

## 3. LEVEL GENERATION ALGORITHM

Endless, strip-based procedural generation. Maintain a `nextSpawnY`; whenever `nextSpawnY < cameraTop + 480`, generate the next **strip** (one screen height, 480 pt) of content. Cull everything > 100 pt below the camera bottom. Keep ~10–16 platforms alive [E]. Use difficulty scalar `d = min(score / 50000, 1)` for interpolation, with the early game additionally gated by absolute score thresholds below.

### 3.1 Vertical spacing (gap between consecutive *bounceable* platforms)
Sample `gap = uniform(gapMin, gapMax)`; interpolate by score:

| Score | gapMin | gapMax | ≈ bounceable platforms/screen |
|---|---|---|---|
| 0 | 30 | 60 | 8–12 |
| 2,500 | 40 | 80 | 6–9 |
| 10,000 | 55 | 100 | 5–7 |
| 25,000 | 70 | 120 | 4–5 |
| 50,000+ | 80 | **140** | 2–4 |

Hard ceiling: gap ≤ 140 pt (< 150 apex, leaving margin) [C: gaps approach but never exceed jump height]. All numbers between rows: linear interpolation [DEFAULT]. Horizontal x: uniform in [0, 320−57], subject to §3.5 reachability.

### 3.2 Platform type probabilities (weights, % of *spawned* platforms)
Brown, exploding are non-bounceable decoys — they are spawned **in addition to** the bounceable chain (see §3.5), interleaved at random offsets, not in place of it.

| Score band | Green | Blue (h) | Gray (v) | White | Movable | — Brown decoy rate | — Exploding rate |
|---|---|---|---|---|---|---|---|
| 0–1,000 | 92 | 0 | 0 | 8 | 0 | 0.15/strip→ | 0 |
| 1,000–3,000 | 72 | 12 | 0 | 14 | 2* | 1/strip | 0 |
| 3,000–6,000 | 58 | 18 | 4 | 18 | 2* | 1.5/strip | 0.3/strip |
| 6,000–13,000 | 42 | 24 | 6 | 24 | 4* | 2/strip | 0.6/strip |
| 13,000–30,000 | 26 | 30 | 8 | 30 | 6 | 3/strip | 0.8/strip |
| 30,000+ | 12 | 34 | 8 | 38 | 8 | 4/strip | 1/strip |

*Movable platforms "rare, mostly above ~13,000" [C] — below 13,000 spawn only if the strip would otherwise be a void set-piece. Entire table is [E/DEFAULT] (no official tables were ever published); the documented constraints it must satisfy: green monotonically ↓ (can approach zero at extreme height), blue/white/brown ↑ with altitude, blue speed ↑, gray rarer than blue, first screens are all green [C].

### 3.3 Item spawn rules (power-ups sit on top of platforms)
Attach only to **green or blue** platforms (never brown/white/exploding/gray/movable) [C/O], positioned at one end of the platform, scrolling with it. Per-eligible-platform roll, with minimum-score gates and a global cooldown: after a propeller/jetpack/trampoline spawns, no other big boost within the next 1,000 score [DEFAULT].

| Item | Gate (score ≥) | Chance per eligible platform | Resulting frequency |
|---|---|---|---|
| Spring | 0 | 5% | several per 1,000–2,000 score [C "most common"] |
| Trampoline | 1,000 | 1.2% | slightly rarer than spring [C] |
| Shield | 2,500 | 0.8% (+ forced placement: 30% of monster spawns put a shield 150–250 pt below the monster [C placement, DEFAULT rate]) | |
| Spring shoes | 4,000 | 0.5% | |
| Propeller hat | 2,000 | 0.4% | ~once per few thousand score [E] |
| Jetpack | 5,000 | 0.25% | rarest spawned item [C order: spring > trampoline > shield/shoes > propeller > jetpack] |

All gates/chances [DEFAULT] tuned to the documented rarity ordering.

### 3.4 Hazard spawn rules
**Mutual exclusion rule:** each 480-pt strip contains at most ONE hazard (monster formation OR UFO formation OR black hole) OR a tricky-platform set-piece — never stacked [C/O: "a screen has a hazard OR a tricky platform puzzle"].

| Hazard | Gate | Frequency (chance per strip) | Notes |
|---|---|---|---|
| Monster | 1,500 [E; sources say 1,000–2,500] | ramp 0.15 → 0.45 as d: 0→1 | Type chosen from roster (§4.3) weighted toward weaker types early |
| Boss ("Terrifier") | 15,000 [DEFAULT; moved lower in 1.13.4] | 0.03, min 8,000 score between bosses [DEFAULT] | |
| UFO | 3,000 [DEFAULT] | ramp 0.08 → 0.25 | Double formation ≥ 20,000 (25% of UFO spawns), triple ≥ 30,000 (15%) [DEFAULT gates; formations C] |
| Black hole | 5,000 [DEFAULT, "slightly later than monsters"] | ramp 0.05 → 0.35; above 20,000 black holes become the dominant, more tightly-placed threat [O] | Always placed to one side; never centered on the only route [O] |

**Set-pieces** (scripted strips, replace normal generation for that strip; ≥ 3,000 score apart [DEFAULT]):
- *Monster roadblock* (≥ 10,000): a platform-sitting monster directly on the only reachable platform — player must shoot it or stomp it (stomp-only variant: gap above is reachable only via the bounce off the monster) [C, v1.7/1.15].
- *Triple monster roadblock* (≥ 25,000) [C, v1.15].
- *Spring ladder* (once, near **40,000**): 5 consecutive spring-topped platforms with a horizontally flying monster between springs 2–3 [C].
- *Void crossing* (≥ 13,000): a 300–420 pt vertical void whose only route is a movable (draggable) platform spawned mid-void, or a spring at the void base [DEFAULT design honoring documented movable-platform role].

### 3.5 Safety / reachability rules (hard guarantees)
1. Maintain a **golden chain**: every strip's bounceable platforms must include a chain where each consecutive gap ≤ 140 pt vertically AND horizontal offset reachable given jump airtime (|Δx| ≤ 140 pt or wrap-adjacent) [C: guaranteed reachability, patched in v1.7].
2. Brown and exploding platforms are never part of the golden chain; they're distractors only [C].
3. White platforms MAY be chain links (they support one bounce) but two consecutive whites must not be the only route across a gap > 100 pt [DEFAULT].
4. A black hole's capture radius must not intersect a 60-pt-wide corridor around the golden chain path [O/DEFAULT].
5. A monster on the golden chain must be killable (never placed such that side-contact is unavoidable: keep ≥ 90 pt lateral clearance to the previous platform's launch point, except in deliberate roadblock set-pieces where stomping is the intended solution) [DEFAULT].
6. Springs/trampolines never spawn on the same platform as a monster [DEFAULT].
7. If a strip ends up unsolvable after hazard placement, regenerate the strip (validation pass before commit) [DEFAULT].

---

## 4. ENTITIES AND BEHAVIORS

### 4.1 The Doodler
Four-legged yellow-green creature with trunk/snout. States: `bouncing` (side-facing, faces tilt direction; distinct L/R sprites), `shooting` (front-facing, nose up, held 0.5 s after last shot [DEFAULT]), `flipping` (trampoline somersault / spring fast somersault), `propeller`, `jetpack`, `shoes` (springs drawn on feet), `shielded` (bubble overlay), `dead-tumble` (limp, rotating, collision off), `sucked` (shrink+spiral into black hole), `abducted` (drawn up into UFO, shrinking). Squash-stretch on every landing (squash to 85% height for ~0.1 s [DEFAULT]). Passes through platforms from below; collides feet-first only when falling [C].

### 4.2 Platforms (all 57×15 pt)
| Type | Color/look | Behavior |
|---|---|---|
| Normal | Green | Static; bounces |
| Moving-H | Blue | Ping-pongs horizontally, reverses at edges; speed per §2; bounces; can carry items |
| Moving-V | Gray-blue | Oscillates vertically per §2; bounces; rarer than blue |
| Broken | Brown/tan, crack down middle | On feet contact: NO bounce — snaps in two halves that rotate apart and fall off-screen with crack sound; Doodler falls through. Late-game variants may drift horizontally (≥ 25,000, 30% of browns [DEFAULT]) |
| One-shot | White, cloud-like | Bounces once at full strength, then fades out (0.2 s) with poof sound; never disappears without contact |
| Exploding | Yellow → red | Timer per §2: yellow on entry, turns red, fizzes, detonates with boom; if Doodler is standing on it (or within 30 pt above [DEFAULT]) at detonation there is no support — Doodler falls (blast itself is not lethal [DEFAULT]); bounces normally before detonation |
| Movable | Dark gray-blue, 4-arrow glyph | Draggable with a finger anywhere on screen (touch-drag moves it, one at a time); after the Doodler bounces on it once, converts to a normal green platform; shows one-time hint text on first-ever encounter |

### 4.3 Power-ups
Behavior + physics per §2. Visuals per §8. Pickup rules: spring/trampoline trigger only when the Doodler's feet land **on the item itself** (item AABB, not the whole platform) [C]; wearables (hat, jetpack, shoes, shield) are collected by touching them from any direction while falling onto their platform region [DEFAULT: item AABB overlap]. Only one wearable active at a time; collecting a new one while flying is ignored [DEFAULT]. Stats hooks: increment jetpack/propeller flight counters on activation.

### 4.4 Monsters (classic roster, 9 types) [C archetypes; HP per Report 1]
All: killed by N projectile hits or ONE stomp (stomp = normal bounce for Doodler + squish sound); side/below contact = death (unless shield/powered flight); each broadcasts the looping warble warning starting ~1 screen before entering view [C]; killed monsters (shot) fall off-screen with crash sound; stomped monsters flatten then fall.

| # | Type | Movement | HP (shots) |
|---|---|---|---|
| 1 | Blue winged hoverer | Hovers in place, slight side-to-side wobble (±15 pt, 0.5 Hz) [DEFAULT amplitudes] | 1 |
| 2 | Green oval 3-eyed sitter | Static, sits on a platform | 2 |
| 3 | Big green fire-breather | Static/slow drift, large (60 pt) | 2 |
| 4 | Purple 6-legged flier | Flies horizontally across full screen, wraps? No — reverses at edges [DEFAULT] | 1 |
| 5 | Red flier | Horizontal flier, faster | 1 |
| 6 | Big blue bouncer | Bounces between two platforms (vertical hop cycle) | 1 |
| 7 | Flat green bouncer ("flathead") | Bounces in place | 3 |
| 8 | Blue one-eyed side-to-side flier | Sinusoidal horizontal patrol | 1 |
| 9 | **Boss "The Terrifier"** | Flies, actively climbs to stay level with/above the Doodler blocking the path (matches camera ascent at ~80 pt/s [DEFAULT]); still dies to a single stomp | **5** |

### 4.5 UFO
Classic saucer with under-glow beam. Hovers near strip top with slow horizontal drift (±30 pt, 20 pt/s [DEFAULT]). Looping theremin hum + sparse beep whenever on/near screen. Contact with beam cone or hull sides → abduction death (Doodler pulled up under the saucer, shrinking, ~1 s, then game over). Shootable: 1 hit [DEFAULT] → destroyed (falls, spinning). Stompable on hull top → destroyed + normal bounce [C, v1.13.3]. Formations: double (side by side, one gap) and triple (V formation spanning most of the screen width, one safe slot) [C]; each UFO independently killable; increment "UFOs shot" stat.

### 4.6 Black hole
Ø ≈ 100 pt black blob, torn-paper look with scribbled ring. Silent until triggered. Static. Indestructible; projectiles pass over it. Within pull radius (80 pt): applies centripetal acceleration; within capture radius (55 pt): control removed, Doodler spirals/shrinks into center over ~0.8 s with suction sound → game over. Shield does NOT protect [C]. Jetpack/propeller do NOT protect (per §2 conflict resolution).

### 4.7 Projectiles
Small round pellets from the snout; 3–4 fired dots visible in a burst spread of ±3° jitter [DEFAULT single pellet per tap; jitter optional]. Straight-line constant velocity; collide with monsters/UFOs (circle-vs-AABB); pass through platforms and black holes; despawn above screen top.

---

## 5. CAMERA, SCORE, AND DEATH RULES

- **Camera:** scrolls up only. When Doodler's y exceeds 240 (screen midpoint) the surplus is applied to the world (everything shifts down); Doodler is never drawn above midline while climbing normally; camera never scrolls down; content below the bottom edge is culled forever [C].
- **Score:** `score = max altitude climbed` (accumulate camera scroll distance; falling back never subtracts; re-climbing adds nothing until previous max passed). Displayed top-left, integer, counts up live. No points for kills or pickups — item "values" are literally the altitude they gain [C].
- **Death conditions** (no health system):
  1. **Fall:** Doodler fully below screen bottom having missed all platforms → falling slide-whistle plays as he drops; camera does not follow; short beat, then game-over panel [C]. (Report 4 says the view follows him down — [CONFLICT]; majority says camera never scrolls down → camera stays.)
  2. **Monster contact (side/below):** hit sound; Doodler enters limp tumble, platform collision disabled, falls through everything off the bottom, then game over [C].
  3. **Black hole:** suction animation at hole position (no fall) → game over [C].
  4. **UFO:** drawn up into saucer, shrinking → game over [C].
- **Shield** negates only death #2. Powered flight negates #2 and #4 while active (per §2).
- On death: submit score to local table (and Game Center); update stats.

---

## 6. SCREENS AND UI FLOW

All screens share the graph-paper background and hand-drawn lettering (see §8). Flow: `Menu → Game → GameOver → (Play Again → Game | Menu)`; `Menu → Scores`, `Menu → Options`; `Resume` on menu when a run is paused.

### 6.1 Main menu
- Hand-lettered "Doodle Jump" logo (tilted, marker style); Doodler idly bouncing on a green platform, boing sound each bounce [C].
- Hand-scribbled text buttons (no boxes): **play**, **scores**, **options**; **resume** appears iff a paused run exists [C]. (Lima Sky News / cross-promo omitted.)
- First launch: brief "how to play" overlay (tilt to move, tap to shoot, don't fall) [C v1.3].

### 6.2 In-game HUD
- **Top strip:** manila-toned paper band across the top with a torn/ripped bottom edge; **score top-left** (hand-written numerals); **pause glyph top-right** [C].
- **Pause:** limited to **5 pauses per game** ("to keep gameplay fair"); pause overlay shows resume + menu + remaining pause count; 6th attempt shows "no pauses left" [C rule, DEFAULT presentation]. Auto-pause on app background does not count against the limit [DEFAULT].
- **Score markers:** horizontal pencil dashed lines drawn in the playfield/margins at the exact altitudes of: your previous best (labeled with your name), local top-10 scores, recent local scores, and (when available) Game Center friends' scores — each labeled "name — score" in scribble text [C].
- One-time contextual hints (movable platform) as floating hand-written text [C].

### 6.3 Game over
- Doodler exits per death animation; falling whistle if applicable; then hand-drawn tilted **"GAME OVER!"** panel slides in on the paper: "your score: N", "your best: M", editable **name field** (taps up the iOS keyboard; this is the name used on markers and the local table; also the future easter-egg input), buttons **play again** and **menu** [C]. New-high-score celebratory scribble if beaten [DEFAULT].

### 6.4 Scores screen
- Local top-10 table (rank, name, score, date [DEFAULT]) + button to Game Center leaderboard. 
- **Stats panel:** games played, high score, average score, total jumps, jetpack flights, propeller-hat flights, UFOs shot; **reset scores & stats** button with confirm [C].

### 6.5 Options
- **Sound on/off** (note: disabling sound removes the monster/UFO early-warning — intentional coupling, keep it) [C].
- **Directional shooting on/off** (off = always straight up) [C].
- **Calibrate tilt** (capture current device attitude as neutral) [C].
- No handedness setting; portrait-only, no rotation [C].

---

## 7. AUDIO DESIGN (SFX only — no background music; audio session `.ambient` so user music plays through)

Palette character: sparse, dry (no reverb), cartoonish, mouth-noise-like [C]. Synthesize (or record) to these descriptions; internal names from the original asset dump given for traceability.

| Event | Original file | Synthesizable description |
|---|---|---|
| Platform bounce | `jump.wav` | THE signature. ~0.15–0.2 s springy pluck; jaw-harp / plucked-rubber-band timbre, mid register (~300–500 Hz fundamental), instant attack, fast upward pitch flick then damped decay — a fat water-droplet "bloip". Same sample every bounce, incl. menu |
| Spring | `feder` | Brighter, tighter metallic coil "boi-oi-oing", higher-pitched than bounce, 0.3–0.4 s, audible pitch rise with slight wobble/ring |
| Trampoline | `trampoline` | Deeper, rounder "doiiing", longer wobble (~0.5 s), lower fundamental than spring |
| Spring shoes | `springshoes` | The tight spring boing, replayed on each of the 6 boosted bounces |
| Broken platform | `lomise` | Dry short wooden crack/snap; filtered noise burst, no pitch sweep, ~0.15 s |
| White platform vanish | `bijeli` | Soft airy "poof", ~0.2 s, gentle noise puff with quick fade |
| Exploding platform | `explodingplatform`, `2` | Fizz/crackle sizzle during yellow→red arming, then a muffled papery "bang" (low thump + noise, ~0.3 s) |
| Shoot | `pucanje`, `pucanje2` | Soft breathy "pew" mouth-pop, ~0.1 s, slight downward pitch; alternates 2 variants on rapid fire |
| Projectile hits monster | `monsterpogodak` | Squelchy wet thud, ~0.15 s |
| Monster proximity | `monsterblizu` | Famous looping garbled vocal warble — wobbly gargled babble ("rom-de-rom-de-rom"), low-mid pitch, strong vibrato; loops while a monster is near and **starts before it scrolls into view** (early-warning function) |
| Monster stomped | `jumponmonster` | Squashy splat + immediate boing |
| Monster killed (shot) | `monster-crash` | Tumbling crash/clatter as it falls, ~0.4 s |
| UFO ambient | `ufo` + `ufo-beep` | Continuous theremin-like wavering sci-fi hum (sine w/ slow vibrato, electronic timbre), looping while on/near screen; occasional sparse high beep |
| UFO shot down | `ufopogodak` | Metallic clunk + descending sputter |
| UFO abduction | `usaugateufo` | Rising suction sweep (~1 s) as the Doodler is drawn up |
| Black hole | `crnarupa` | ~1 s airy suction whoosh with descending pitch as the Doodler spirals in |
| Fall / lose | `pada` | Descending slide-whistle glissando, ~1 s — the iconic death sound |
| Jetpack | `jetpack1–5` | Sputtery rocket thrust rumble — low raspy "brrrr"/raspberry; separate ignition burst, loop, and burnout-sputter variants across the flight |
| Propeller hat | `propeller1–5` | Light airy flutter/whir (card-in-bicycle-spokes / small fan), softer and higher than jetpack, sustained loop for the longer slower ascent; wind-down at expiry |
| Game start | `start.wav` | Short bright hand-drawn fanfare doodle, <1 s [DEFAULT interpretation] |

Mixing: bounce ~ −6 dB relative to alerts; proximity loops duck when a boost is active [DEFAULT]. Sound-off setting mutes everything (including warnings).

---

## 8. ART DIRECTION (hand-drawn-on-graph-paper; all sprites procedurally drawable)

**Global conceit:** the entire game is pencil/marker on a sheet of graph paper. Off-white/cream ground (#F7F4E9 [DEFAULT]) with a fine light grid (0.5-pt lines, ~13-pt cell, pale blue-gray #C9D4D8 at ~35% [DEFAULT]) covering playfield AND every menu. Left/right screen edges carry darker scribbled/hatched vertical margin bands (~10 pt wide, graphite hatching) like a worn notebook edge. All strokes look hand-drawn: 1.5–2.5 pt outlines with slight jitter/waviness (render with low-frequency perlin offset on paths [DEFAULT]), flat or lightly hatched fills, no gradients, no clean typefaces anywhere — irregular marker lettering (a hand-style font or hand-authored glyphs).

| Sprite | Description for procedural drawing |
|---|---|
| **Doodler** | ~40×45 pt yellow-green (#B7C838 [DEFAULT]) blob: rounded rectangular body, four stubby tube legs (two front, two back), a trunk/snout protruding from the face, two simple dot-in-circle eyes. Side view (L/R mirrored) for normal play; front view with snout pointed straight up for shooting pose. Dark olive outline, slight belly shading hatch. Squash frame (85% height, 110% width). Limp-tumble frame: X eyes, legs splayed, rotates while falling |
| **Green platform** | 57×15 pt rounded-rect (corner r≈7), grass-green fill (#6DBE45 [DEFAULT]), darker green outline, one lighter highlight stroke along top |
| **Blue platform** | Same shape, sky-blue (#4FA9E2), subtle motion feel via slightly streaked outline |
| **Gray platform** | Same shape, gray-blue (#8FA6B2) |
| **Brown platform** | Same shape, tan/brown (#B98A4F) with a jagged dark crack drawn down the middle; break state = two halves split along the crack, rotating ±20° as they fall |
| **White platform** | Same shape, white fill, soft gray outline, cloud-like slightly puffier corners; fades to 0 alpha on use |
| **Exploding platform** | Same shape; yellow (#E8C830) arming state, red (#D9482B) armed state with tiny drawn spark/fuse squiggles; detonation = scribbled star-burst flash + smoke puffs, platform gone |
| **Movable platform** | Same shape, dark gray-blue (#4A5E78) with four small white arrows (up/down/left/right) drawn in the center |
| **Spring** | ~16×12 pt (compressed): 3–4 coil loops in gray pencil on a small base, sitting on one end of a platform; extends to ~16×22 with stretched coils on trigger |
| **Trampoline** | ~34×10 pt: dark horizontal band (canvas) on two small angled legs, cross-hatched surface; flexes concave on trigger |
| **Propeller hat** | Small blue-gray beanie cap (~18 pt) with a two-blade propeller on top; when worn, blades animate as a spinning blurred ellipse; falls off spinning slowly at expiry |
| **Jetpack** | ~16×24 pt metal canister pair with strap, pencil-gray with hatching; worn on the back; exhaust = scribbled orange/yellow flame triangles in 3 sizes (ignition big, cruise medium, burnout small sputtering puffs) |
| **Spring shoes** | Two tiny spring coils with shoe caps drawn under the Doodler's feet; compress/extend each bounce; tumble away when spent |
| **Shield** | Translucent blue circle outline (2 concentric wobbly strokes, ~54 pt Ø) around the Doodler with occasional sparkle ticks; blinks before expiry |
| **Projectile** | 4-pt filled dark dot with a thin motion tail |
| **Monsters (goofy, not scary)** | Scribble creatures, flat saturated fills + dark outlines, simple googly eyes: (1) blue teardrop body w/ two small flapping wings; (2) green horizontal oval, 3 stalked eyes, sits on platform; (3) big green lumpy blob, wide toothy mouth; (4) purple round body, 6 stick legs, antennae; (5) red diamond body, small wings; (6) big blue vertical oval, tall as ~2 platform gaps; (7) flat wide green pancake with two eyes on top ("flathead"); (8) blue sphere with a single big central eye; (9) Boss: largest (~70 pt), spiky dark silhouette, angry brows, small wings — visibly distinct menace. Stomped frame: flattened pancake with X eyes. Hit flash: white blink 0.05 s |
| **UFO** | Classic saucer ~60×30 pt: gray dome + wide elliptical brim with 3 drawn lights; translucent yellow beam cone (~60 pt wide at base, wobbling hand-drawn edges) projecting downward; abduction = Doodler scales down while translating up into the dome |
| **Black hole** | ~100 pt irregular black blob (wobbly, torn-paper edge in white showing through) with a scribbled dark-gray spiral ring around it; victims shrink + rotate into center |
| **HUD strip** | Manila paper band (#EAE0C8), full width ×~36 pt + safe-area, bottom edge drawn as an irregular torn line with small tears; score numerals hand-written style, dark graphite |
| **Score markers** | Dashed hand-drawn horizontal pencil line across playfield at the score's altitude, with "name — score" scribbled at the margin end |
| **Buttons/lettering** | Pure hand-lettered words in dark marker, slightly rotated (±3°); pressed state = slightly enlarged + darker. "GAME OVER!" = big rough marker caps, tilted ~−8° |
| **Menu logo** | "Doodle Jump" in fat, uneven marker letters, two lines, slight arc, with a small doodled star/scribble accent |

Rendering approach: author all sprites as SKShapeNode/Core Graphics vector paths with jittered strokes rasterized once into a texture atlas at 3× (or ship pre-rendered PNGs from an authoring script), so the hand-drawn look is consistent and cheap at runtime [DEFAULT].

---

## APPENDIX A — Resolved conflicts (choices made)
1. **Trampoline height:** 520 pt (measured wiki table, R1+R3) over ~700 pt (R2).
2. **Jump apex:** 150 pt (two clone derivations + physical measurement chain) over ~190 pt (R3 footage estimate).
3. **Spring shoes:** 6 bounces × ~345 pt (R3 measured total 2,068) over 5 × 500 (R2).
4. **Propeller/jetpack gains:** 1,736 / 3,307 (measured table) over looser ranges.
5. **Holographic + shifting platforms:** excluded (R1 dates both to v2.6/2011; R3 claims v1.7/classic).
6. **Powered-flight invulnerability:** immune to monsters+UFO during jetpack AND propeller (R1 explicit; propeller "shreds monsters" documented); black hole always lethal.
7. **Camera on fall death:** does not follow downward (R2/R3) over R4's "view follows him down".
8. **Release date:** March 15, 2009 (Apr 6 was v1.0.3).
9. **Rocket:** genuinely classic-era (Apr 2010) but Space-theme-only → not spawned in the notebook theme.

---

## APPENDIX B — Open questions

- Holographic (relocating) and shifting (swap-on-jump) platforms: Report 3 places a holographic set-piece in v1.7 (Sep 2009) while Report 1 explicitly dates both to v2.6 (Sep 2011). Excluded from scope; verify against period gameplay footage if strict fidelity to late-classic builds is required.
- Trampoline boost height: 520 vs ~700 pt across sources; 520 chosen from the measured wiki table. Playtest against 2009-2010 footage and tune.
- Jump apex 150 pt vs ~190 pt (footage estimate): 150 chosen; if late-game 140-pt gaps feel too tight in playtesting, raise apex and gap ceiling together.
- Hazard immunity during propeller-hat flight is genuinely ambiguous in sources (jetpack immunity is better attested). Currently: immune during both. Confirm with footage.
- Exact spawn-gate altitudes for monsters (1,000-2,500), UFOs, and black holes were never published; all gates and per-strip probabilities in Section 3.4 are defaults needing playtest calibration against the difficulty curve of real runs.
- Tilt gain (400 pt/s per g, max 300 pt/s) is a community-converged estimate, not measured; calibrate feel against original hardware capture if available.
- UFO hit points (1 shot assumed) and exploding-platform timer values (1.5 s + 1.5 s) are defaults with no source figures.
- Whether original spring/trampoline required landing precisely on the item AABB vs anywhere on the platform is stated for spring only; wearable pickup rules are inferred.
- Score-marker data source: original used Lima Sky's live global server (dead). Spec substitutes local scores + Game Center friends; confirm this is acceptable for the recreation.
