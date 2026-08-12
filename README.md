# Doodle Classic

A from-scratch, historically minded recreation of the *classic-era
(2009–2010) tilt-to-jump vertical platformer* — the gameplay generation
defined by the original Doodle Jump — built as a modern iOS game for
personal, non-commercial play. No ads, no in-app purchases, no gimmicks:
just the loop.

**Everything in this repository is original work.** The gameplay mechanics
were recreated from first principles using published research: version
histories, developer interviews, contemporaneous 2009–2010 reviews, fan-wiki
measurements, and clone-author physics analyses (the distilled findings live
in [`docs/RESEARCH.md`](docs/RESEARCH.md)). All art is drawn programmatically
at runtime in an original hand-doodled style — the hero is our own critter
design — and every sound effect is synthesized in code. No assets, code,
character designs, or audio from Lima Sky's Doodle Jump (or from any clone of
it) are included: game *mechanics* are recreatable; their *assets and
trademarks* are not, and this project deliberately contains none of them.

## What's recreated (the classic 2009–2010 feature set)

- **Physics tuned to measurement** — ~150-pt jump apex on a floaty ~1.36 s
  parabola in the original 320×480 coordinate space; score = altitude,
  one original screen ≈ 480 points
- **Tilt controls** — proportional accelerometer steering with horizontal
  screen wrap and a calibration option
- **Platforms** — static green, horizontally moving blue (faster with
  height), crumbling brown, vanish-after-one-bounce white, vertically
  oscillating gray, yellow→red exploding, and draggable four-arrow movables
- **Boosts, measured heights** — spring (352 pt), trampoline (520 pt),
  propeller beanie (~1,700 pt), spring shoes (6 spring bounces), jetpack
  (~3,300 pt with ignition/cruise/burnout), force shield (monsters only —
  nothing saves you from black holes or falling)
- **Hazards** — three monster archetypes (hoverer, two-shot sitter,
  full-width flier) with the looping early-warning warble, stompable and
  shootable; UFO with abduction beam (doubles up high); big black holes
  that always win
- **Shooting** — tap to fire pellets; straight-up like the launch build, or
  the era's directional aiming via the options toggle
- **Camera & scoring** — camera only ever scrolls up, runs end below the
  bottom edge, monster hits cause the limp tumbling fall
- **Presentation** — graph-paper world, torn-paper HUD strip, five-pause
  fairness rule, hand-scribbled menus, game-over card with name entry,
  local top-10 whose scores are inked as named marker lines at their real
  altitudes in the world, and the classic stats sheet (jumps, flights,
  UFOs shot…)

Deliberately not recreated: the online/global leaderboards (service long
gone), alternate themes, name-code easter eggs, boss monsters, and the
Space-theme-only rocket — see `docs/RESEARCH.md` for the historical
reasoning.

## Requirements

- Xcode 16 or newer
- iOS 16+ (tested target: current iPhones; portrait only)
- No dependencies — pure Swift + SpriteKit + CoreMotion + AVFoundation

## Build & install on your iPhone

1. Open `DoodleClassic.xcodeproj` in Xcode.
2. Select the *DoodleClassic* target → **Signing & Capabilities** → pick your
   personal team (a free Apple ID works) and change the bundle identifier to
   something unique to you if Xcode asks.
3. Plug in your iPhone, select it as the run destination, press **Run**.
4. On the phone: *Settings → General → VPN & Device Management* → trust your
   developer certificate the first time.

With a free (non-paid) Apple ID the app signature expires after 7 days —
just press Run again to refresh it. A paid developer account signs for a year.

## Project layout

```
DoodleClassic/
  AppDelegate.swift        app entry
  GameViewController.swift SpriteKit host, 320-pt logical width
  GameGeometry.swift       coordinate space + every tuning constant
  ArtFactory.swift         all sprites drawn in code (Core Graphics)
  SoundFactory.swift       all SFX synthesized in code (PCM → AVAudioPlayer)
  TiltInput.swift          CoreMotion steering + calibration
  Settings.swift           the classic options (aim toggle, tilt zero)
  ScoreStore.swift         local top-10 (UserDefaults)
  Stats.swift              the classic stats counters
  Entities.swift           hero, platforms, boosts, monsters, UFO, holes
  LevelGenerator.swift     altitude-banded spawning per the research
  GameScene.swift          the game: physics, collisions, camera, HUD
  MenuScene.swift          menu + scores/stats screens
  OptionsScene.swift       sound / aim / calibrate
  GameOverScene.swift      torn-paper end card + name entry
docs/RESEARCH.md           the distilled mechanics research (with sources)
```
