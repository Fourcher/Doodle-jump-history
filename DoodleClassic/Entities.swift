import SpriteKit
import UIKit

// MARK: - Hero

final class HeroNode: SKSpriteNode {

    enum Flight { case none, propeller(TimeInterval), jetpack(TimeInterval) }

    var velocity = CGVector.zero
    var flight: Flight = .none
    var shootPoseRemaining: TimeInterval = 0
    /// Spring-strength bounces left on the worn spring shoes (0 = none).
    var springShoeBouncesLeft = 0
    /// Seconds of force shield remaining (0 = none).
    var shieldRemaining: TimeInterval = 0
    /// Positive xScale faces right; remember the last direction so the
    /// hero doesn't flip while the phone is held level.
    private var facingRight = true

    private let propellerOverlay: SKSpriteNode
    private let jetpackOverlay: SKSpriteNode
    private let shoesOverlay: SKSpriteNode
    private let shieldOverlay: SKSpriteNode

    /// Distance from node center down to the soles of the feet.
    var feetOffset: CGFloat { 21 }
    var halfWidth: CGFloat { 15 }

    var isFlying: Bool {
        if case .none = flight { return false }
        return true
    }

    var hasShield: Bool { shieldRemaining > 0 }

    init() {
        propellerOverlay = SKSpriteNode(texture: ArtFactory.propellerFrames[0])
        propellerOverlay.isHidden = true
        jetpackOverlay = SKSpriteNode(texture: ArtFactory.jetpackFrames[0])
        jetpackOverlay.isHidden = true
        shoesOverlay = SKSpriteNode(texture: ArtFactory.springShoesTex)
        shoesOverlay.isHidden = true
        shieldOverlay = SKSpriteNode(texture: ArtFactory.shieldBubbleTex)
        shieldOverlay.isHidden = true

        let tex = ArtFactory.heroSide
        super.init(texture: tex, color: .clear, size: tex.size())
        zPosition = 20

        propellerOverlay.position = CGPoint(x: 0, y: 26)
        propellerOverlay.zPosition = 2
        addChild(propellerOverlay)

        jetpackOverlay.position = CGPoint(x: -16, y: -4)
        jetpackOverlay.zPosition = -1
        addChild(jetpackOverlay)

        shoesOverlay.position = CGPoint(x: 0, y: -19)
        shoesOverlay.zPosition = 1
        addChild(shoesOverlay)

        shieldOverlay.position = .zero
        shieldOverlay.zPosition = 3
        addChild(shieldOverlay)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    // MARK: worn items

    func beginPropeller() {
        flight = .propeller(Tuning.propellerDuration)
        propellerOverlay.isHidden = false
        propellerOverlay.removeAllActions()
        propellerOverlay.run(.repeatForever(.animate(with: ArtFactory.propellerFrames,
                                                     timePerFrame: 0.05)))
        SoundFactory.shared.start(.propeller)
    }

    func beginJetpack() {
        flight = .jetpack(Tuning.jetpackDuration)
        jetpackOverlay.isHidden = false
        jetpackOverlay.removeAllActions()
        jetpackOverlay.run(.repeatForever(.animate(with: ArtFactory.jetpackFrames,
                                                   timePerFrame: 0.06)))
        SoundFactory.shared.start(.rocket)
    }

    func endFlight() {
        flight = .none
        propellerOverlay.isHidden = true
        propellerOverlay.removeAllActions()
        jetpackOverlay.isHidden = true
        jetpackOverlay.removeAllActions()
        SoundFactory.shared.stop(.propeller)
        SoundFactory.shared.stop(.rocket)
    }

    func beginSpringShoes() {
        springShoeBouncesLeft = Tuning.springShoeBounces
        shoesOverlay.isHidden = false
    }

    /// Consumes one shoe bounce; hides the shoes when they wear out.
    func useShoeBounce() {
        springShoeBouncesLeft -= 1
        if springShoeBouncesLeft <= 0 {
            springShoeBouncesLeft = 0
            shoesOverlay.isHidden = true
        }
    }

    func beginShield() {
        shieldRemaining = Tuning.shieldDuration
        shieldOverlay.isHidden = false
        shieldOverlay.removeAllActions()
        shieldOverlay.alpha = 1
    }

    func tickShield(dt: TimeInterval) {
        guard shieldRemaining > 0 else { return }
        shieldRemaining -= dt
        if shieldRemaining <= 0 {
            shieldRemaining = 0
            shieldOverlay.isHidden = true
            shieldOverlay.removeAllActions()
        } else if shieldRemaining < 2.0 && shieldOverlay.action(forKey: "blink") == nil {
            shieldOverlay.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.15, duration: 0.15),
                .fadeAlpha(to: 1.0, duration: 0.15),
            ])), withKey: "blink")
        }
    }

    /// A monster hit spends the shield: pop the bubble.
    func consumeShield() {
        shieldRemaining = 0
        shieldOverlay.removeAllActions()
        shieldOverlay.isHidden = true
        SoundFactory.shared.play(.whitePoof)
    }

    /// Advance flight timers; returns true while still airborne on a boost.
    /// The lift profiles follow the classic feel: the propeller spins up
    /// briefly and holds a slow cruise; the jetpack has a distinct
    /// ignition ramp, fast cruise, and sputtering burnout.
    func tickFlight(dt: TimeInterval) -> Bool {
        switch flight {
        case .none:
            return false
        case .propeller(let remaining):
            let left = remaining - dt
            if left <= 0 { endFlight(); return false }
            flight = .propeller(left)
            let elapsed = Tuning.propellerDuration - left
            let spin = min(1, elapsed / Tuning.propellerSpinupTime)
            velocity.dy = Tuning.propellerCruiseSpeed * CGFloat(spin)
            return true
        case .jetpack(let remaining):
            let left = remaining - dt
            if left <= 0 { endFlight(); return false }
            flight = .jetpack(left)
            let elapsed = Tuning.jetpackDuration - left
            if elapsed < Tuning.jetpackIgnitionTime {
                velocity.dy = Tuning.jetpackCruiseSpeed *
                    CGFloat(elapsed / Tuning.jetpackIgnitionTime)
            } else if left < Tuning.jetpackBurnoutTime {
                let t = CGFloat(1 - left / Tuning.jetpackBurnoutTime)
                velocity.dy = Tuning.jetpackCruiseSpeed -
                    (Tuning.jetpackCruiseSpeed - Tuning.jetpackBurnoutFloor) * t
            } else {
                velocity.dy = Tuning.jetpackCruiseSpeed
            }
            return true
        }
    }

    /// The little landing squash the whole game's feel hangs on.
    func squash() {
        removeAction(forKey: "squash")
        yScale = abs(yScale) * 0.85
        run(.scaleY(to: 1.0, duration: 0.12), withKey: "squash")
    }

    func updatePose() {
        if shootPoseRemaining > 0 {
            texture = ArtFactory.heroUp
            xScale = abs(xScale)
            return
        }
        texture = ArtFactory.heroSide
        if velocity.dx > 18 { facingRight = true }
        if velocity.dx < -18 { facingRight = false }
        xScale = facingRight ? abs(xScale) : -abs(xScale)
    }
}

// MARK: - Platforms

final class PlatformNode: SKSpriteNode {

    let kind: PlatformKind
    /// Set when the platform can no longer be landed on (crumbled/used/blown).
    var isSpent = false
    /// Horizontal slide for blue platforms, points/second.
    var slideVelocity: CGFloat = 0
    var boost: BoostNode?

    // vertical oscillation (gray platforms)
    private var baseY: CGFloat = 0
    private var verticalPhase: CGFloat = .random(in: 0...(2 * .pi))
    private var verticalSpeed: CGFloat = 0

    // exploding platforms: armed once on screen, then a short fuse
    private var fuseRemaining: TimeInterval = Tuning.explodingFuse
    private var armed = false
    private var turnedRed = false

    /// Movable platforms turn into ordinary greens after their first bounce.
    private(set) var isDraggable = false

    init(spec: PlatformSpec) {
        kind = spec.kind
        let tex: SKTexture
        switch spec.kind {
        case .green: tex = ArtFactory.platformGreenTex
        case .blue: tex = ArtFactory.platformBlueTex
        case .brown: tex = ArtFactory.platformBrownTex
        case .white: tex = ArtFactory.platformWhiteTex
        case .grayVertical: tex = ArtFactory.platformGrayTex
        case .exploding: tex = ArtFactory.platformYellowTex
        case .movable: tex = ArtFactory.platformMovableTex
        }
        super.init(texture: tex, color: .clear, size: tex.size())
        position = spec.position
        baseY = spec.position.y
        zPosition = 10
        if spec.kind == .blue {
            let speed = spec.moveSpeed
            slideVelocity = Bool.random() ? speed : -speed
        }
        if spec.kind == .grayVertical {
            verticalSpeed = max(spec.moveSpeed * 0.7, 20)
        }
        if spec.kind == .movable {
            isDraggable = true
        }
        if let boostKind = spec.boost {
            let node = BoostNode(kind: boostKind)
            let maxOffset = max(4, Tuning.platformSize.width / 2 - node.size.width / 2 - 4)
            node.position = CGPoint(x: CGFloat.random(in: -maxOffset...maxOffset),
                                    y: Tuning.platformSize.height / 2 + node.size.height / 2 - 3)
            node.zPosition = 1
            addChild(node)
            boost = node
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    var topY: CGFloat { position.y + Tuning.platformSize.height / 2 }
    var halfWidth: CGFloat { Tuning.platformSize.width / 2 }

    /// Per-frame movement + fuse logic. `cameraTop` is the world y of the
    /// top of the view, used to arm exploding platforms when they appear.
    func update(dt: TimeInterval, cameraTop: CGFloat) {
        if slideVelocity != 0 {
            position.x += slideVelocity * CGFloat(dt)
            let bound = GameGeometry.worldWidth - halfWidth - 4
            if position.x > bound { position.x = bound; slideVelocity = -abs(slideVelocity) }
            if position.x < halfWidth + 4 { position.x = halfWidth + 4; slideVelocity = abs(slideVelocity) }
        }
        if kind == .grayVertical {
            verticalPhase += CGFloat(dt) * verticalSpeed / (Tuning.verticalPlatformRange / 2)
            position.y = baseY + sin(verticalPhase) * Tuning.verticalPlatformRange / 2
        }
        if kind == .exploding, !isSpent {
            if !armed, position.y < cameraTop {
                armed = true
                SoundFactory.shared.play(.fuse)
            }
            if armed {
                fuseRemaining -= dt
                if !turnedRed, fuseRemaining < Tuning.explodingFuse * 0.55 {
                    turnedRed = true
                    texture = ArtFactory.platformRedTex
                    run(.repeatForever(.sequence([.fadeAlpha(to: 0.55, duration: 0.09),
                                                  .fadeAlpha(to: 1.0, duration: 0.09)])),
                        withKey: "flash")
                }
                if fuseRemaining <= 0 { explode() }
            }
        }
    }

    private func explode() {
        isSpent = true
        removeAction(forKey: "flash")
        SoundFactory.shared.play(.boom)
        boost?.removeFromParent()
        boost = nil
        // quick doodle "poof": expanding scribble ring
        let puff = SKShapeNode(circleOfRadius: 6)
        puff.strokeColor = UIColor(red: 0.55, green: 0.35, blue: 0.2, alpha: 0.9)
        puff.lineWidth = 3
        puff.position = position
        puff.zPosition = 12
        parent?.addChild(puff)
        puff.run(.sequence([.group([.scale(to: 4.5, duration: 0.3),
                                    .fadeOut(withDuration: 0.3)]),
                            .removeFromParent()]))
        removeFromParent()
    }

    /// Brown platforms snap and drop in two pieces.
    func crumble() {
        guard !isSpent else { return }
        isSpent = true
        SoundFactory.shared.play(.crumble)
        let pieces = [(ArtFactory.brownFragmentLeft, CGFloat(-14)),
                      (ArtFactory.brownFragmentRight, CGFloat(14))]
        for (tex, dx) in pieces {
            let piece = SKSpriteNode(texture: tex)
            piece.position = CGPoint(x: position.x + dx, y: position.y)
            piece.zPosition = 9
            parent?.addChild(piece)
            let drift = SKAction.moveBy(x: dx * 1.4, y: -420, duration: 1.1)
            drift.timingMode = .easeIn
            piece.run(.sequence([.group([drift,
                                         .rotate(byAngle: dx > 0 ? 1.7 : -1.7, duration: 1.1)]),
                                 .removeFromParent()]))
        }
        run(.sequence([.fadeOut(withDuration: 0.08), .removeFromParent()]))
    }

    /// White platforms give one bounce and dissolve.
    func vanish() {
        guard !isSpent else { return }
        isSpent = true
        SoundFactory.shared.play(.whitePoof)
        run(.sequence([.fadeOut(withDuration: 0.22), .removeFromParent()]))
    }

    /// A movable platform settles into an ordinary green after its first
    /// bounce.
    func settleAfterDrag() {
        guard isDraggable else { return }
        isDraggable = false
        texture = ArtFactory.platformGreenTex
    }

    /// Drag target for movable platforms, clamped inside the walls.
    func dragTo(x: CGFloat, y: CGFloat) {
        guard isDraggable else { return }
        position.x = max(halfWidth + 4,
                         min(GameGeometry.worldWidth - halfWidth - 4, x))
        position.y = y
        baseY = y
    }
}

// MARK: - Boosts

final class BoostNode: SKSpriteNode {

    let kind: BoostKind
    var isConsumed = false

    init(kind: BoostKind) {
        self.kind = kind
        let tex: SKTexture
        switch kind {
        case .spring: tex = ArtFactory.springIdle
        case .trampoline: tex = ArtFactory.trampolineTex
        case .propeller: tex = ArtFactory.propellerHat(blade: 0)
        case .jetpack: tex = ArtFactory.jetpackPickup
        case .springShoes: tex = ArtFactory.springShoesTex
        case .shield: tex = ArtFactory.shieldPickupTex
        }
        super.init(texture: tex, color: .clear, size: tex.size())
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    /// Boosts you wear are collected on any touch; springs and
    /// trampolines only fire when landed on.
    var isWearable: Bool {
        switch kind {
        case .propeller, .jetpack, .springShoes, .shield: return true
        case .spring, .trampoline: return false
        }
    }

    func springOpen() {
        texture = ArtFactory.springOpen
        size = ArtFactory.springOpen.size()
        position.y += 5
    }
}

// MARK: - Monsters

final class MonsterNode: SKSpriteNode {

    enum Archetype {
        case hoverer    // wobbles in place, 1 shot
        case sitter     // parked, 2 shots
        case flier      // patrols the full screen width, 1 shot
    }

    let archetype: Archetype
    var isDead = false
    var hitPoints: Int
    private var baseX: CGFloat = 0
    private var phase: CGFloat = .random(in: 0...(2 * .pi))
    private var flierDirection: CGFloat = Bool.random() ? 1 : -1
    private var fallSpeed: CGFloat = 0

    init(spec: HazardSpec) {
        switch spec.kind {
        case .monsterWinged:
            archetype = .hoverer
            hitPoints = 1
        case .monsterTall:
            archetype = .sitter
            hitPoints = 2
        case .monsterFlier:
            archetype = .flier
            hitPoints = 1
        default:
            archetype = .hoverer
            hitPoints = 1
        }
        let tex: SKTexture
        switch archetype {
        case .hoverer: tex = ArtFactory.monsterWingedFrames[0]
        case .sitter: tex = ArtFactory.monsterTall
        case .flier: tex = ArtFactory.monsterFlierFrames[0]
        }
        super.init(texture: tex, color: .clear, size: tex.size())
        position = spec.position
        baseX = spec.position.x
        zPosition = 15
        switch archetype {
        case .hoverer:
            run(.repeatForever(.animate(with: ArtFactory.monsterWingedFrames,
                                        timePerFrame: 0.14)))
        case .sitter:
            run(.repeatForever(.sequence([.rotate(toAngle: 0.06, duration: 0.7),
                                          .rotate(toAngle: -0.06, duration: 0.7)])))
        case .flier:
            run(.repeatForever(.animate(with: ArtFactory.monsterFlierFrames,
                                        timePerFrame: 0.1)))
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    func update(dt: TimeInterval) {
        if isDead {
            fallSpeed += CGFloat(dt) * 1500
            position.y -= fallSpeed * CGFloat(dt)
            return
        }
        switch archetype {
        case .hoverer:
            phase += CGFloat(dt) * 1.1
            position.x = baseX + sin(phase) * 26
        case .sitter:
            break
        case .flier:
            position.x += flierDirection * 60 * CGFloat(dt)
            let margin: CGFloat = 34
            if position.x > GameGeometry.worldWidth - margin {
                position.x = GameGeometry.worldWidth - margin
                flierDirection = -1
            } else if position.x < margin {
                position.x = margin
                flierDirection = 1
            }
            xScale = flierDirection > 0 ? abs(xScale) : -abs(xScale)
        }
    }

    /// A pellet hit. Returns true if this one killed it.
    func takeHit() -> Bool {
        guard !isDead else { return false }
        hitPoints -= 1
        if hitPoints <= 0 {
            die()
            return true
        }
        // flinch
        run(.sequence([.fadeAlpha(to: 0.4, duration: 0.06),
                       .fadeAlpha(to: 1.0, duration: 0.06)]))
        return false
    }

    func die() {
        guard !isDead else { return }
        isDead = true
        removeAllActions()
        SoundFactory.shared.play(.stomp)
        yScale = -abs(yScale)   // belly-up on the way down
    }

    var hitRadius: CGFloat {
        switch archetype {
        case .hoverer: return 18
        case .sitter: return 20
        case .flier: return 22
        }
    }
}

// MARK: - UFO

final class UFONode: SKSpriteNode {

    var isDead = false
    private var baseX: CGFloat = 0
    private var phase: CGFloat = .random(in: 0...(2 * .pi))
    private var fallSpeed: CGFloat = 0
    private let beam: SKShapeNode

    init(spec: HazardSpec) {
        let beamPath = UIBezierPath()
        beamPath.move(to: CGPoint(x: -8, y: -6))
        beamPath.addLine(to: CGPoint(x: 8, y: -6))
        beamPath.addLine(to: CGPoint(x: 26, y: -66))
        beamPath.addLine(to: CGPoint(x: -26, y: -66))
        beamPath.close()
        beam = SKShapeNode(path: beamPath.cgPath)
        beam.fillColor = UIColor(red: 0.98, green: 0.9, blue: 0.35, alpha: 0.22)
        beam.strokeColor = UIColor(red: 0.98, green: 0.9, blue: 0.35, alpha: 0.4)
        beam.lineWidth = 1

        let tex = ArtFactory.ufoTex
        super.init(texture: tex, color: .clear, size: tex.size())
        position = spec.position
        baseX = spec.position.x
        zPosition = 15
        beam.zPosition = -1
        addChild(beam)
        beam.run(.repeatForever(.sequence([.fadeAlpha(to: 0.45, duration: 0.5),
                                           .fadeAlpha(to: 1.0, duration: 0.5)])))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    func update(dt: TimeInterval) {
        if isDead {
            fallSpeed += CGFloat(dt) * 1500
            position.y -= fallSpeed * CGFloat(dt)
            zRotation += CGFloat(dt) * 3
            return
        }
        phase += CGFloat(dt) * 0.8
        position.x = baseX + sin(phase) * Tuning.ufoDriftSpeed
    }

    func die() {
        guard !isDead else { return }
        isDead = true
        removeAllActions()
        beam.removeFromParent()
        SoundFactory.shared.play(.stomp)
    }

    /// The abduction zone under the saucer.
    func beamCatches(_ point: CGPoint) -> Bool {
        guard !isDead else { return false }
        let dx = point.x - position.x
        let dy = position.y - point.y   // how far below the saucer
        return dy > -6 && dy < 66 && abs(dx) < 8 + dy * 0.3
    }

    var hitRadius: CGFloat { 26 }
}

// MARK: - Black hole

final class BlackHoleNode: SKSpriteNode {

    init(spec: HazardSpec) {
        let tex = ArtFactory.blackHoleTex
        super.init(texture: tex, color: .clear, size: tex.size())
        position = spec.position
        zPosition = 5
        run(.repeatForever(.rotate(byAngle: -2 * .pi, duration: 6)))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    var pullRadius: CGFloat { Tuning.blackHolePullRadius }
    var captureRadius: CGFloat { Tuning.blackHoleCaptureRadius }
}

// MARK: - Pellet

final class PelletNode: SKSpriteNode {

    let velocity: CGVector

    init(position: CGPoint, velocity: CGVector) {
        self.velocity = velocity
        let tex = ArtFactory.pelletTex
        super.init(texture: tex, color: .clear, size: tex.size())
        self.position = position
        zPosition = 18
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    func update(dt: TimeInterval) {
        position.x += velocity.dx * CGFloat(dt)
        position.y += velocity.dy * CGFloat(dt)
    }
}
