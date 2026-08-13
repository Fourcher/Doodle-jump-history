import CoreGraphics
import Foundation

enum PlatformKind {
    case green        // static
    case blue         // slides horizontally
    case brown        // crumbles, never supports a bounce
    case white        // vanishes after one bounce
    case grayVertical // oscillates up and down
    case exploding    // yellow → red → boom
    case movable      // drag it with a finger; turns green after one bounce
}

enum BoostKind {
    case spring, trampoline, propeller, jetpack, springShoes, shield
}

enum HazardKind {
    case monsterWinged, monsterTall, monsterFlier, ufo, blackHole
}

struct PlatformSpec {
    let kind: PlatformKind
    let position: CGPoint
    let boost: BoostKind?
    /// Movement speed for blue/gray platforms, points/second.
    var moveSpeed: CGFloat = 0
}

struct HazardSpec {
    let kind: HazardKind
    let position: CGPoint
}

/// Emits the endless climb one rung at a time, the classic way: a
/// guaranteed ladder of landable platforms whose spacing stretches with
/// altitude, decorated with crumbling browns and armed exploders, boosts
/// on the greens and blues, and at most one hazard in any stretch.
///
/// The tables follow the researched difficulty curve: gaps 30–60 pt on
/// the first screens growing to 80–140 near two vertical miles up, green
/// share falling from ~90% toward nothing, movers speeding up, hazards
/// ramping in after their score gates (monsters ~1,500, UFOs ~3,000,
/// black holes ~5,000).
final class LevelGenerator {

    private var rng: SystemRandomNumberGenerator = .init()
    /// Altitude (world y) of the last landable rung emitted.
    private(set) var topY: CGFloat = 0
    private var lastRungX: CGFloat = GameGeometry.worldWidth / 2
    private var lastHazardY: CGFloat = -10_000
    private var lastBigBoostY: CGFloat = -10_000
    /// When a monster spawns, sometimes park a shield on the rung below it.
    private var pendingShield = false

    private let margin: CGFloat = 34   // keep platforms clear of the walls

    /// A hazard sits 80–250 pt above the rung it was placed against, which
    /// is exactly where later rungs get generated. Without a memory of where
    /// hazards went, a black hole could land squarely on a platform the
    /// player has no choice but to aim for — and a black hole cannot be shot
    /// and ignores both the shield and powered flight. Every hazard
    /// therefore records a keep-out box that later rungs must avoid.
    private struct KeepOut {
        let position: CGPoint
        let radiusX: CGFloat
        let radiusY: CGFloat
    }
    private var keepOuts: [KeepOut] = []

    private func recordKeepOut(_ kind: HazardKind, at position: CGPoint) {
        // Radii cover the hazard's lethal reach plus half a platform plus
        // half the hero, so no landable spot on the rung is inside it.
        let padding = Tuning.platformSize.width / 2 + 15
        switch kind {
        case .blackHole:
            keepOuts.append(KeepOut(position: position,
                                    radiusX: Tuning.blackHoleCaptureRadius + padding,
                                    radiusY: Tuning.blackHoleCaptureRadius + 35))
        case .ufo:
            // The abduction beam hangs 66 pt below the saucer and widens
            // as it falls, so the box reaches downward.
            keepOuts.append(KeepOut(position: CGPoint(x: position.x, y: position.y - 33),
                                    radiusX: 28 + padding,
                                    radiusY: 52))
        case .monsterWinged, .monsterTall, .monsterFlier:
            keepOuts.append(KeepOut(position: position,
                                    radiusX: 22 + padding,
                                    radiusY: 30))
        }
    }

    /// How far clear of every keep-out box a rung at (x, y) would be.
    /// Negative means it overlaps one.
    private func clearance(x: CGFloat, y: CGFloat) -> CGFloat {
        var worst = CGFloat.greatestFiniteMagnitude
        for k in keepOuts where abs(y - k.position.y) < k.radiusY {
            worst = min(worst, abs(x - k.position.x) - k.radiusX)
        }
        return worst
    }

    /// Choose the rung's x within jumping reach of the last one, avoiding
    /// any hazard already committed at this altitude.
    private func safeRungX(near previousX: CGFloat, y: CGFloat) -> CGFloat {
        let reach: CGFloat = 130
        let lo = max(margin, previousX - reach)
        let hi = min(GameGeometry.worldWidth - margin, previousX + reach)
        guard hi > lo else {
            return max(margin, min(GameGeometry.worldWidth - margin, previousX))
        }
        for _ in 0..<12 {
            let candidate = random(lo...hi)
            if clearance(x: candidate, y: y) >= 0 { return candidate }
        }
        // Nothing clean within reach: take the roomiest spot available
        // rather than dropping the player onto a hazard.
        var best = lo
        var bestClearance = -CGFloat.greatestFiniteMagnitude
        var probe = lo
        let step = max(4, (hi - lo) / 24)
        while probe <= hi {
            let c = clearance(x: probe, y: y)
            if c > bestClearance { bestClearance = c; best = probe }
            probe += step
        }
        return best
    }

    init(startY: CGFloat) {
        topY = startY
    }

    /// 0 → fresh run, 1 → fully ramped (~50,000 altitude). The curve is
    /// square-rooted where the era's difficulty rose fastest early.
    private var ramp: CGFloat {
        sqrt(min(1, topY / 50_000))
    }

    private func random(_ range: ClosedRange<CGFloat>) -> CGFloat {
        CGFloat.random(in: range, using: &rng)
    }

    private func chance(_ p: CGFloat) -> Bool {
        random(0...1) < p
    }

    /// Generate the next rung plus any decoration/hazards around it.
    func nextChunk() -> (platforms: [PlatformSpec], hazards: [HazardSpec]) {
        var platforms: [PlatformSpec] = []
        var hazards: [HazardSpec] = []
        let f = ramp
        let altitude = topY

        // --- spacing: 30–60 pt sheets early, 80–140 pt leaps later ---
        let gap = random((30 + 50 * f)...(60 + 80 * f))
        let y = topY + gap

        // --- pick the rung platform (must be landable) ---
        let kind = rungKind(f: f, altitude: altitude)
        let moveSpeed = 40 + 60 * f * f   // blue/gray get faster with height

        // Reachable from the last rung, and clear of any hazard already
        // committed at this height.
        let x = safeRungX(near: lastRungX, y: y)
        lastRungX = x
        keepOuts.removeAll { $0.position.y < y - 700 }

        // --- boost on static or sliding rungs ---
        var boost: BoostKind? = nil
        if kind == .green || kind == .blue {
            boost = rollBoost(altitude: altitude, y: y)
        }
        platforms.append(PlatformSpec(kind: kind, position: CGPoint(x: x, y: y),
                                      boost: boost, moveSpeed: moveSpeed))

        // --- side platforms: extra greens early, decoys later ---
        if f < 0.3 && chance(0.5 - f) {
            let sx = wallClampedX(away: x, minDistance: 80)
            platforms.append(PlatformSpec(kind: .green,
                                          position: CGPoint(x: sx, y: y + random(8...30)),
                                          boost: nil))
        }
        if chance(0.10 + 0.45 * f) {
            let sx = wallClampedX(away: x, minDistance: 70)
            platforms.append(PlatformSpec(kind: .brown,
                                          position: CGPoint(x: sx, y: y + random(20...44)),
                                          boost: nil))
        }
        if altitude > 3000, chance(0.02 + 0.13 * f) {
            let sx = wallClampedX(away: x, minDistance: 70)
            platforms.append(PlatformSpec(kind: .exploding,
                                          position: CGPoint(x: sx, y: y + random(24...50)),
                                          boost: nil))
        }

        // --- hazards: well separated, never on the rung itself ---
        if y - lastHazardY > 500 {
            hazards = rollHazards(f: f, altitude: altitude, rungX: x, y: y)
            if !hazards.isEmpty {
                lastHazardY = y
                for hazard in hazards {
                    recordKeepOut(hazard.kind, at: hazard.position)
                }
            }
        }

        topY = y
        return (platforms, hazards)
    }

    private func rungKind(f: CGFloat, altitude: CGFloat) -> PlatformKind {
        // weights follow the researched bands: green 92→~10, blue 0→34,
        // white 8→38, gray 0→8, movable 0→6 (movables only above ~13,000)
        let green = max(10, 92 - 85 * f)
        let blue = altitude > 1000 ? 34 * f : 0
        let gray = altitude > 3000 ? 8 * f : 0
        let white = 8 + 30 * f
        let movable: CGFloat = altitude > 13_000 ? 6 * f : 0
        let total = green + blue + gray + white + movable
        var roll = random(0...total)
        if roll < green { return .green }
        roll -= green
        if roll < blue { return .blue }
        roll -= blue
        if roll < gray { return .grayVertical }
        roll -= gray
        if roll < white { return .white }
        return .movable
    }

    private func rollBoost(altitude: CGFloat, y: CGFloat) -> BoostKind? {
        if pendingShield {
            pendingShield = false
            return .shield
        }
        let bigBoostReady = y - lastBigBoostY > 1000
        if bigBoostReady {
            if altitude > 5000, chance(0.0025) { lastBigBoostY = y; return .jetpack }
            if altitude > 2000, chance(0.004) { lastBigBoostY = y; return .propeller }
            if altitude > 4000, chance(0.005) { return .springShoes }
            if altitude > 1000, chance(0.012) { lastBigBoostY = y; return .trampoline }
        }
        if altitude > 2500, chance(0.008) { return .shield }
        if chance(0.05) { return .spring }
        return nil
    }

    private func rollHazards(f: CGFloat, altitude: CGFloat, rungX: CGFloat,
                             y: CGFloat) -> [HazardSpec] {
        // per-rung chances ≈ researched per-screen chances / rungs-per-screen
        let monsterChance: CGFloat = altitude > 1500 ? 0.022 + 0.043 * f : 0
        let ufoChance: CGFloat = altitude > 3000 ? 0.012 + 0.024 * f : 0
        let holeChance: CGFloat = altitude > 5000 ? 0.007 + 0.043 * f : 0
        let roll = random(0...1)
        if roll < monsterChance {
            let hx = wallClampedX(away: rungX, minDistance: 60)
            let kinds: [HazardKind] = [.monsterWinged, .monsterTall, .monsterFlier]
            let kind = kinds[Int(random(0...2.999))]
            // the classic generator liked to leave a shield just below a monster
            pendingShield = chance(0.3)
            return [HazardSpec(kind: kind,
                               position: CGPoint(x: hx, y: y + random(60...110)))]
        }
        if roll < monsterChance + ufoChance {
            // The saucer's beam hangs 66 pt below it, so it has to clear the
            // rung horizontally as well as sit high enough that the beam's
            // mouth is above the arc of a jump taken from that rung.
            let hx = wallClampedX(away: rungX, minDistance: 70)
            let first = HazardSpec(kind: .ufo,
                                   position: CGPoint(x: hx, y: y + random(200...250)))
            // double-UFO formations arrive high up
            if altitude > 20_000, chance(0.25) {
                let offset: CGFloat = hx < GameGeometry.worldWidth / 2
                    ? random(110...150)
                    : -random(110...150)
                let secondX = max(margin,
                                  min(GameGeometry.worldWidth - margin, hx + offset))
                let second = HazardSpec(kind: .ufo,
                                        position: CGPoint(x: secondX,
                                                          y: first.position.y + random(-20...20)))
                return [first, second]
            }
            return [first]
        }
        if roll < monsterChance + ufoChance + holeChance {
            // always off to one side of the path
            let hx: CGFloat = rungX < GameGeometry.worldWidth / 2
                ? random(210...270)
                : random(50...110)
            return [HazardSpec(kind: .blackHole,
                               position: CGPoint(x: hx, y: y + random(80...140)))]
        }
        return []
    }

    /// An x position at least `minDistance` from `x`, inside the walls.
    private func wallClampedX(away x: CGFloat, minDistance: CGFloat) -> CGFloat {
        let leftRoom = x - margin
        let rightRoom = GameGeometry.worldWidth - margin - x
        let goRight = rightRoom > leftRoom
        let base = goRight
            ? random((x + minDistance)...max(x + minDistance, GameGeometry.worldWidth - margin))
            : random(min(margin, x - minDistance)...(x - minDistance))
        return max(margin, min(GameGeometry.worldWidth - margin, base))
    }

    /// The opening screens: a floor-to-ceiling sheet of easy greens so the
    /// first seconds feel like the classic's gentle start.
    func starterPlatforms(sceneHeight: CGFloat, heroX: CGFloat) -> [PlatformSpec] {
        var specs: [PlatformSpec] = [
            PlatformSpec(kind: .green, position: CGPoint(x: heroX, y: 40), boost: nil)
        ]
        var y: CGFloat = 40
        while y < sceneHeight {
            y += random(35...55)
            let x = random(margin...(GameGeometry.worldWidth - margin))
            specs.append(PlatformSpec(kind: .green, position: CGPoint(x: x, y: y), boost: nil))
        }
        topY = y
        lastRungX = specs.last?.position.x ?? heroX
        return specs
    }
}
