import SpriteKit
import UIKit

/// The climb itself. Simulation is hand-rolled (no SKPhysicsWorld), the
/// way the era's games did it: swept feet-vs-platform-top tests while
/// falling, straight velocity integration, a camera that only ever rises.
final class GameScene: SKScene {

    private enum State {
        case playing
        case dyingByMonster   // bounced off a monster, tumbling down
        case abducted         // pulled into the UFO
        case swallowed        // pulled into a black hole
        case fallingOut       // dropped below the screen
        case finished
    }

    private let world = SKNode()
    private let cam = SKCameraNode()
    private let hero = HeroNode()

    private var platforms: [PlatformNode] = []
    private var monsters: [MonsterNode] = []
    private var ufos: [UFONode] = []
    private var holes: [BlackHoleNode] = []
    private var pellets: [PelletNode] = []

    private var generator: LevelGenerator!
    private var state: State = .playing
    private var lastUpdate: TimeInterval = 0
    private var shootCooldownRemaining: TimeInterval = 0

    private var heroStartY: CGFloat = 0
    private var maxAltitude: CGFloat = 0
    private var score: Int { Int(maxAltitude * Tuning.scorePerPoint) }
    private let boardBefore = ScoreStore.entries

    // HUD & pause
    private var scoreLabel: SKLabelNode!
    private var pauseButton: SKNode!
    private var pauseOverlay: SKNode?
    private var gamePaused = false
    private var pausesLeft = Tuning.pausesPerGame
    private var safeTop: CGFloat = 0

    // touch routing: a drag on a movable platform must not fire a shot
    private var draggedPlatform: PlatformNode?
    private var dragTouch: UITouch?
    private var shownDragHint = false

    private var backgroundTiles: [SKSpriteNode] = []
    private var backgroundTileHeight: CGFloat = 0

    // MARK: - setup

    override func didMove(to view: SKView) {
        backgroundColor = ArtFactory.paper
        camera = cam
        cam.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(cam)
        addChild(world)

        safeTop = view.safeAreaInsets.top * (GameGeometry.worldWidth / view.bounds.width)

        setupBackground()
        setupHUD()

        heroStartY = 40 + Tuning.platformSize.height / 2 + hero.feetOffset
        hero.position = CGPoint(x: size.width / 2, y: heroStartY)
        hero.velocity = CGVector(dx: 0, dy: Tuning.jumpVelocity)
        world.addChild(hero)

        generator = LevelGenerator(startY: 0)
        for spec in generator.starterPlatforms(sceneHeight: size.height,
                                               heroX: hero.position.x) {
            addPlatform(spec)
        }
        setupScoreMarkers()

        TiltInput.shared.start()
        SoundFactory.shared.play(.bounce)

        NotificationCenter.default.addObserver(self, selector: #selector(autoPause),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)
    }

    override func willMove(from view: SKView) {
        NotificationCenter.default.removeObserver(self)
        SoundFactory.shared.stopAllLoops()
    }

    private func setupBackground() {
        let cell: CGFloat = 32
        backgroundTileHeight = ceil(size.height / cell) * cell
        let tex = ArtFactory.backgroundTile(size: CGSize(width: size.width,
                                                         height: backgroundTileHeight))
        for i in 0..<3 {
            let tile = SKSpriteNode(texture: tex)
            tile.anchorPoint = .zero
            tile.position = CGPoint(x: 0, y: CGFloat(i - 1) * backgroundTileHeight)
            tile.zPosition = -100
            world.addChild(tile)
            backgroundTiles.append(tile)
        }
    }

    private func setupHUD() {
        let strip = SKSpriteNode(texture: ArtFactory.hudStrip(width: size.width))
        strip.anchorPoint = CGPoint(x: 0.5, y: 1)
        strip.position = CGPoint(x: 0, y: size.height / 2)
        strip.zPosition = 100
        strip.size = CGSize(width: size.width, height: 34 + safeTop)
        cam.addChild(strip)

        scoreLabel = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        scoreLabel.fontSize = 20
        scoreLabel.fontColor = ArtFactory.ink
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.verticalAlignmentMode = .top
        scoreLabel.position = CGPoint(x: -size.width / 2 + 10,
                                      y: size.height / 2 - safeTop - 5)
        scoreLabel.zPosition = 101
        scoreLabel.text = "0"
        cam.addChild(scoreLabel)

        let pause = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        pause.text = "❚❚"
        pause.fontSize = 16
        pause.fontColor = ArtFactory.ink
        pause.verticalAlignmentMode = .top
        pause.horizontalAlignmentMode = .right
        pause.position = CGPoint(x: size.width / 2 - 12,
                                 y: size.height / 2 - safeTop - 7)
        pause.zPosition = 101
        pause.name = "pause"
        cam.addChild(pause)
        pauseButton = pause
    }

    /// The signature social hook: previous scores inked straight onto the
    /// paper at the altitude where each run ended.
    private func setupScoreMarkers() {
        for (index, entry) in boardBefore.prefix(10).enumerated() where entry.score > 50 {
            let y = heroStartY + CGFloat(entry.score) / Tuning.scorePerPoint
            let isBest = index == 0
            let color = isBest
                ? UIColor(red: 0.75, green: 0.25, blue: 0.2, alpha: 0.85)
                : UIColor(white: 0.45, alpha: 0.6)

            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: size.width, y: 0))
            let line = SKShapeNode(path: path.copy(dashingWithPhase: 0, lengths: [8, 6]))
            line.strokeColor = color
            line.lineWidth = isBest ? 2 : 1
            line.position = CGPoint(x: 0, y: y)
            line.zPosition = 4
            world.addChild(line)

            let label = SKLabelNode(fontNamed: "MarkerFelt-Thin")
            label.text = isBest ? "best · \(entry.score)" : "\(entry.score)"
            label.fontSize = isBest ? 12 : 10
            label.fontColor = color
            label.horizontalAlignmentMode = .right
            label.verticalAlignmentMode = .bottom
            label.position = CGPoint(x: size.width - 8, y: y + 3)
            label.zPosition = 4
            world.addChild(label)
        }
    }

    // MARK: - spawning

    private func addPlatform(_ spec: PlatformSpec) {
        let node = PlatformNode(spec: spec)
        world.addChild(node)
        platforms.append(node)
        if spec.kind == .movable, !shownDragHint, !UserDefaults.standard.bool(forKey: "dragHintShown") {
            shownDragHint = true
            UserDefaults.standard.set(true, forKey: "dragHintShown")
            let hint = SKLabelNode(fontNamed: "MarkerFelt-Thin")
            hint.text = "drag these platforms with your finger!"
            hint.fontSize = 13
            hint.fontColor = UIColor(white: 0.35, alpha: 1)
            hint.position = CGPoint(x: size.width / 2, y: node.position.y - 28)
            hint.zPosition = 40
            world.addChild(hint)
            hint.run(.sequence([.wait(forDuration: 6), .fadeOut(withDuration: 1),
                                .removeFromParent()]))
        }
    }

    private func addHazard(_ spec: HazardSpec) {
        switch spec.kind {
        case .monsterWinged, .monsterTall, .monsterFlier:
            let node = MonsterNode(spec: spec)
            world.addChild(node)
            monsters.append(node)
        case .ufo:
            let node = UFONode(spec: spec)
            world.addChild(node)
            ufos.append(node)
        case .blackHole:
            let node = BlackHoleNode(spec: spec)
            world.addChild(node)
            holes.append(node)
        }
    }

    private func spawnAhead() {
        while generator.topY < cam.position.y + size.height {
            let chunk = generator.nextChunk()
            chunk.platforms.forEach(addPlatform)
            chunk.hazards.forEach(addHazard)
        }
    }

    private func cleanupBelow() {
        let floor = cam.position.y - size.height * 0.7
        platforms.removeAll { node in
            if node.position.y < floor || node.parent == nil {
                node.removeFromParent(); return true
            }
            return false
        }
        monsters.removeAll { node in
            if node.position.y < floor { node.removeFromParent(); return true }
            return false
        }
        ufos.removeAll { node in
            if node.position.y < floor { node.removeFromParent(); return true }
            return false
        }
        holes.removeAll { node in
            if node.position.y < floor { node.removeFromParent(); return true }
            return false
        }
        pellets.removeAll { node in
            if node.position.y > cam.position.y + size.height ||
                abs(node.position.x - size.width / 2) > size.width {
                node.removeFromParent(); return true
            }
            return false
        }
    }

    // MARK: - input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let camPoint = touch.location(in: cam)

        if gamePaused {
            handlePauseOverlayTap(camPoint)
            return
        }
        guard state == .playing else { return }
        if pauseButton.calculateAccumulatedFrame().insetBy(dx: -16, dy: -16)
            .contains(camPoint) {
            requestPause()
            return
        }

        // a touch that starts on a movable platform drags it instead of shooting
        let worldPoint = touch.location(in: world)
        if let target = platforms.first(where: { platform in
            platform.isDraggable &&
            platform.calculateAccumulatedFrame().insetBy(dx: -14, dy: -18)
                .contains(worldPoint)
        }) {
            draggedPlatform = target
            dragTouch = touch
            return
        }
        shoot(toward: worldPoint)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = dragTouch, touches.contains(touch),
              let platform = draggedPlatform, platform.parent != nil else { return }
        let p = touch.location(in: world)
        platform.dragTo(x: p.x, y: p.y)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = dragTouch, touches.contains(touch) {
            draggedPlatform = nil
            dragTouch = nil
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func shoot(toward worldPoint: CGPoint) {
        guard shootCooldownRemaining <= 0, !hero.isFlying else { return }
        shootCooldownRemaining = Tuning.shootCooldown
        SoundFactory.shared.play(.shoot)
        hero.shootPoseRemaining = Tuning.shootPoseTime

        var direction = CGVector(dx: 0, dy: 1)
        if Settings.directionalShooting {
            let dx = worldPoint.x - hero.position.x
            let dy = worldPoint.y - hero.position.y
            var angle = atan2(dx, max(dy, 1))   // from straight up
            angle = max(-Tuning.maxShootAngle, min(Tuning.maxShootAngle, angle))
            direction = CGVector(dx: sin(angle), dy: cos(angle))
        }
        let velocity = CGVector(dx: direction.dx * Tuning.projectileSpeed,
                                dy: direction.dy * Tuning.projectileSpeed)
        let pellet = PelletNode(position: CGPoint(x: hero.position.x,
                                                  y: hero.position.y + 20),
                                velocity: velocity)
        world.addChild(pellet)
        pellets.append(pellet)
    }

    // MARK: - pause

    @objc private func autoPause() {
        // backgrounding pauses for free — it doesn't spend one of the five
        if state == .playing && !gamePaused { presentPauseOverlay() }
    }

    private func requestPause() {
        guard pausesLeft > 0 else {
            SoundFactory.shared.play(.button)
            let note = SKLabelNode(fontNamed: "MarkerFelt-Wide")
            note.text = "no pauses left!"
            note.fontSize = 18
            note.fontColor = UIColor(red: 0.75, green: 0.22, blue: 0.18, alpha: 1)
            note.position = CGPoint(x: 0, y: size.height / 2 - safeTop - 60)
            note.zPosition = 150
            cam.addChild(note)
            note.run(.sequence([.wait(forDuration: 1.2), .fadeOut(withDuration: 0.4),
                                .removeFromParent()]))
            return
        }
        pausesLeft -= 1
        presentPauseOverlay()
    }

    private func presentPauseOverlay() {
        guard !gamePaused else { return }
        gamePaused = true
        world.isPaused = true
        SoundFactory.shared.stopAllLoops()

        let overlay = SKNode()
        overlay.zPosition = 200

        let dim = SKSpriteNode(color: UIColor(white: 1, alpha: 0.55), size: size)
        overlay.addChild(dim)

        let panel = SKSpriteNode(texture: ArtFactory.tornPanel(size: CGSize(width: 220, height: 210)))
        overlay.addChild(panel)

        let title = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        title.text = "paused"
        title.fontSize = 30
        title.fontColor = ArtFactory.ink
        title.position = CGPoint(x: 0, y: 52)
        overlay.addChild(title)

        let count = SKLabelNode(fontNamed: "MarkerFelt-Thin")
        count.text = "\(pausesLeft) pause\(pausesLeft == 1 ? "" : "s") left"
        count.fontSize = 14
        count.fontColor = UIColor(white: 0.45, alpha: 1)
        count.position = CGPoint(x: 0, y: 28)
        overlay.addChild(count)

        overlay.addChild(makeButton(text: "resume", name: "resume",
                                    at: CGPoint(x: 0, y: -16)))
        overlay.addChild(makeButton(text: "menu", name: "menu",
                                    at: CGPoint(x: 0, y: -64)))
        cam.addChild(overlay)
        pauseOverlay = overlay
    }

    private func handlePauseOverlayTap(_ point: CGPoint) {
        guard let overlay = pauseOverlay else { return }
        if let node = overlay.childNode(withName: "resume"),
           node.calculateAccumulatedFrame().insetBy(dx: -10, dy: -10).contains(point) {
            SoundFactory.shared.play(.button)
            overlay.removeFromParent()
            pauseOverlay = nil
            gamePaused = false
            world.isPaused = false
            lastUpdate = 0
        } else if let node = overlay.childNode(withName: "menu"),
                  node.calculateAccumulatedFrame().insetBy(dx: -10, dy: -10).contains(point) {
            SoundFactory.shared.play(.button)
            goToMenu()
        }
    }

    private func makeButton(text: String, name: String, at position: CGPoint) -> SKNode {
        let container = SKNode()
        container.name = name
        container.position = position
        let label = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        label.text = text
        label.fontSize = 26
        label.fontColor = ArtFactory.ink
        label.verticalAlignmentMode = .center
        label.name = name
        label.zRotation = 0.03
        container.addChild(label)
        return container
    }

    private func goToMenu() {
        SoundFactory.shared.stopAllLoops()
        TiltInput.shared.stop()
        let menu = MenuScene(size: size)
        menu.scaleMode = scaleMode
        view?.presentScene(menu, transition: .fade(with: ArtFactory.paper, duration: 0.4))
    }

    // MARK: - main loop

    override func update(_ currentTime: TimeInterval) {
        guard !gamePaused else { lastUpdate = currentTime; return }
        if lastUpdate == 0 { lastUpdate = currentTime; return }
        let dt = min(currentTime - lastUpdate, 1.0 / 30.0)
        lastUpdate = currentTime

        switch state {
        case .playing:
            simulate(dt: dt)
        case .dyingByMonster, .fallingOut:
            simulateDeadFall(dt: dt)
        case .abducted, .swallowed, .finished:
            break   // fully driven by SKActions
        }
    }

    private func simulate(dt: TimeInterval) {
        // steering
        hero.velocity.dx = TiltInput.shared.targetVelocity()

        // vertical: boost flight overrides gravity
        if !hero.tickFlight(dt: dt) {
            hero.velocity.dy += Tuning.gravity * CGFloat(dt)
            hero.velocity.dy = max(hero.velocity.dy, Tuning.maxFallSpeed)
        }

        let previousFeet = hero.position.y - hero.feetOffset
        hero.position.x += hero.velocity.dx * CGFloat(dt)
        hero.position.y += hero.velocity.dy * CGFloat(dt)
        wrapHero()

        if hero.shootPoseRemaining > 0 { hero.shootPoseRemaining -= dt }
        if shootCooldownRemaining > 0 { shootCooldownRemaining -= dt }
        hero.tickShield(dt: dt)
        hero.updatePose()

        let feet = hero.position.y - hero.feetOffset
        if hero.velocity.dy < 0 && !hero.isFlying {
            resolveLanding(previousFeet: previousFeet, feet: feet)
        }
        collectPickups()

        let cameraTop = cam.position.y + size.height / 2
        for platform in platforms { platform.update(dt: dt, cameraTop: cameraTop) }
        platforms.removeAll { $0.parent == nil }
        for monster in monsters { monster.update(dt: dt) }
        for ufo in ufos { ufo.update(dt: dt) }
        for pellet in pellets { pellet.update(dt: dt) }

        resolvePellets()
        if hero.isFlying {
            shredMonstersInFlight()
        } else {
            resolveMonsterContact()
            resolveUFOContact()
        }
        // black holes always win, even over a jetpack
        resolveBlackHoles(dt: dt)

        // camera rises with the hero, never sinks
        if hero.position.y > cam.position.y {
            cam.position.y = hero.position.y
        }
        scrollBackground()
        spawnAhead()
        cleanupBelow()
        updateAmbientLoops()

        maxAltitude = max(maxAltitude, hero.position.y - heroStartY)
        scoreLabel.text = "\(score)"

        // dropped past the bottom edge
        if state == .playing,
           hero.position.y + hero.size.height < cam.position.y - size.height / 2 {
            state = .fallingOut
            SoundFactory.shared.stopAllLoops()
            SoundFactory.shared.play(.fall)
            hero.endFlight()
            run(.sequence([.wait(forDuration: 0.9),
                           .run { [weak self] in self?.finishRun() }]))
        }
    }

    /// After a monster hit the hero tumbles limply through everything.
    private func simulateDeadFall(dt: TimeInterval) {
        hero.velocity.dy += Tuning.gravity * CGFloat(dt)
        hero.velocity.dy = max(hero.velocity.dy, Tuning.maxFallSpeed)
        hero.position.y += hero.velocity.dy * CGFloat(dt)
        if state == .dyingByMonster {
            hero.zRotation += CGFloat(dt) * 4
        }
    }

    private func wrapHero() {
        let w = GameGeometry.worldWidth
        if hero.position.x < -hero.halfWidth { hero.position.x += w + hero.halfWidth * 2 }
        if hero.position.x > w + hero.halfWidth { hero.position.x -= w + hero.halfWidth * 2 }
    }

    // MARK: - collisions

    private func resolveLanding(previousFeet: CGFloat, feet: CGFloat) {
        for platform in platforms where !platform.isSpent {
            let top = platform.topY
            guard previousFeet >= top - 1, feet <= top,
                  abs(hero.position.x - platform.position.x)
                      < platform.halfWidth + hero.halfWidth * 0.6 else { continue }

            // a spring or trampoline on this platform catches the feet first
            if let boost = platform.boost, !boost.isConsumed, !boost.isWearable,
               abs(hero.position.x - (platform.position.x + boost.position.x))
                   < boost.size.width / 2 + hero.halfWidth * 0.5 {
                switch boost.kind {
                case .spring:
                    boost.isConsumed = true
                    boost.springOpen()
                    launch(at: Tuning.springVelocity)
                    SoundFactory.shared.play(.spring)
                    somersault(duration: 0.45)
                    return
                case .trampoline:
                    launch(at: Tuning.trampolineVelocity)
                    SoundFactory.shared.play(.trampoline)
                    somersault(duration: 0.6)
                    return
                default:
                    break
                }
            }

            switch platform.kind {
            case .brown:
                platform.crumble()
                continue   // no support — keep falling
            case .white:
                bounce(on: platform)
                platform.vanish()
                return
            case .green, .blue, .grayVertical, .exploding:
                bounce(on: platform)
                return
            case .movable:
                bounce(on: platform)
                platform.settleAfterDrag()
                if draggedPlatform === platform {
                    draggedPlatform = nil
                    dragTouch = nil
                }
                return
            }
        }
    }

    /// A normal platform bounce (spring shoes upgrade it while they last).
    private func bounce(on platform: PlatformNode) {
        if hero.springShoeBouncesLeft > 0 {
            hero.useShoeBounce()
            launch(at: Tuning.springVelocity)
            SoundFactory.shared.play(.spring)
        } else {
            launch(at: Tuning.jumpVelocity)
            SoundFactory.shared.play(.bounce)
        }
        hero.position.y = platform.topY + hero.feetOffset
        hero.squash()
    }

    private func launch(at speed: CGFloat) {
        hero.velocity.dy = speed
        Stats.totalJumps += 1
    }

    private func somersault(duration: TimeInterval) {
        hero.removeAction(forKey: "flip")
        hero.zRotation = 0
        hero.run(.sequence([.rotate(byAngle: 2 * .pi, duration: duration),
                            .run { [weak hero] in hero?.zRotation = 0 }]),
                 withKey: "flip")
    }

    /// Wearable boosts trigger on any touch, not just a landing.
    private func collectPickups() {
        guard !hero.isFlying else { return }
        for platform in platforms {
            guard let boost = platform.boost, !boost.isConsumed,
                  boost.isWearable else { continue }
            let worldPos = CGPoint(x: platform.position.x + boost.position.x,
                                   y: platform.position.y + boost.position.y)
            let dx = hero.position.x - worldPos.x
            let dy = hero.position.y - worldPos.y
            guard dx * dx + dy * dy < 28 * 28 else { continue }
            boost.isConsumed = true
            boost.removeFromParent()
            platform.boost = nil
            SoundFactory.shared.play(.pickup)
            switch boost.kind {
            case .propeller:
                hero.beginPropeller()
                Stats.propellerFlights += 1
            case .jetpack:
                hero.beginJetpack()
                Stats.jetpackFlights += 1
            case .springShoes:
                hero.beginSpringShoes()
            case .shield:
                hero.beginShield()
            case .spring, .trampoline:
                break
            }
        }
    }

    private func resolvePellets() {
        for pellet in pellets {
            guard pellet.parent != nil else { continue }
            for monster in monsters where !monster.isDead {
                let dx = pellet.position.x - monster.position.x
                let dy = pellet.position.y - monster.position.y
                if dx * dx + dy * dy < monster.hitRadius * monster.hitRadius {
                    _ = monster.takeHit()
                    pellet.removeFromParent()
                    break
                }
            }
            guard pellet.parent != nil else { continue }
            for ufo in ufos where !ufo.isDead {
                let dx = pellet.position.x - ufo.position.x
                let dy = pellet.position.y - ufo.position.y
                if dx * dx + dy * dy < ufo.hitRadius * ufo.hitRadius {
                    ufo.die()
                    Stats.ufosShot += 1
                    pellet.removeFromParent()
                    break
                }
            }
        }
        pellets.removeAll { $0.parent == nil }
    }

    /// The propeller (and jetpack) shred any monster they touch.
    private func shredMonstersInFlight() {
        for monster in monsters where !monster.isDead {
            let dx = hero.position.x - monster.position.x
            let dy = hero.position.y - monster.position.y
            let reach = monster.hitRadius + hero.halfWidth
            if dx * dx + dy * dy < reach * reach {
                monster.die()
            }
        }
    }

    private func resolveMonsterContact() {
        for monster in monsters where !monster.isDead {
            let dx = hero.position.x - monster.position.x
            let dy = hero.position.y - monster.position.y
            let reach = monster.hitRadius + hero.halfWidth
            guard dx * dx + dy * dy < reach * reach else { continue }

            let stomping = hero.velocity.dy < 0 &&
                hero.position.y - hero.feetOffset > monster.position.y
            if stomping {
                monster.die()
                launch(at: Tuning.jumpVelocity)
            } else if hero.hasShield {
                hero.consumeShield()
                monster.die()
            } else {
                startMonsterDeath()
            }
            return
        }
    }

    private func startMonsterDeath() {
        state = .dyingByMonster
        SoundFactory.shared.stopAllLoops()
        SoundFactory.shared.play(.fall)
        hero.endFlight()
        hero.shootPoseRemaining = 0
        hero.velocity = CGVector(dx: 0, dy: 260)   // sad little rebound
        for monster in monsters { monster.removeAllActions() }
        run(.sequence([.wait(forDuration: 1.6),
                       .run { [weak self] in self?.finishRun() }]))
    }

    private func resolveUFOContact() {
        for ufo in ufos where !ufo.isDead {
            let stompZone = hero.velocity.dy < 0 &&
                hero.position.y - hero.feetOffset > ufo.position.y + 8
            let dx = hero.position.x - ufo.position.x
            let dy = hero.position.y - ufo.position.y
            let reach = ufo.hitRadius + hero.halfWidth
            let touchingHull = dx * dx + dy * dy < reach * reach

            if touchingHull && stompZone {
                ufo.die()
                Stats.ufosShot += 1
                launch(at: Tuning.jumpVelocity)
                return
            }
            if touchingHull || ufo.beamCatches(hero.position) {
                startAbduction(by: ufo)
                return
            }
        }
    }

    private func startAbduction(by ufo: UFONode) {
        state = .abducted
        SoundFactory.shared.stopAllLoops()
        SoundFactory.shared.play(.abduct)
        hero.endFlight()
        let rise = SKAction.move(to: CGPoint(x: ufo.position.x, y: ufo.position.y - 6),
                                 duration: 0.8)
        rise.timingMode = .easeIn
        hero.run(.group([rise, .scale(to: 0.1, duration: 0.8),
                         .rotate(byAngle: 3 * .pi, duration: 0.8)]))
        let flyOff = SKAction.sequence([
            .wait(forDuration: 0.85),
            .move(by: CGVector(dx: 0, dy: size.height), duration: 0.6),
        ])
        ufo.run(flyOff)
        run(.sequence([.wait(forDuration: 1.6),
                       .run { [weak self] in self?.finishRun() }]))
    }

    private func resolveBlackHoles(dt: TimeInterval) {
        guard state == .playing else { return }
        for hole in holes {
            let dx = hole.position.x - hero.position.x
            let dy = hole.position.y - hero.position.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < hole.captureRadius {
                startSwallow(into: hole)
                return
            }
            if dist < hole.pullRadius, dist > 0 {
                let strength: CGFloat = 250 * (1 - dist / hole.pullRadius)
                hero.velocity.dx += dx / dist * strength * CGFloat(dt) * 4
                hero.position.x += dx / dist * strength * CGFloat(dt) * CGFloat(dt) * 30
                hero.position.y += dy / dist * strength * CGFloat(dt) * CGFloat(dt) * 30
            }
        }
    }

    private func startSwallow(into hole: BlackHoleNode) {
        state = .swallowed
        SoundFactory.shared.stopAllLoops()
        SoundFactory.shared.play(.blackHole)
        hero.endFlight()
        let pull = SKAction.move(to: hole.position, duration: 0.6)
        pull.timingMode = .easeIn
        hero.run(.group([pull, .scale(to: 0.02, duration: 0.6),
                         .rotate(byAngle: 5 * .pi, duration: 0.6)]))
        run(.sequence([.wait(forDuration: 1.2),
                       .run { [weak self] in self?.finishRun() }]))
    }

    // MARK: - ambience

    private func updateAmbientLoops() {
        let half = size.height / 2
        // The warble starts shortly before the monster scrolls into view —
        // the classic early-warning system. The lead is deliberately short
        // (about a fifth of a screen): far enough to warn, close enough that
        // the sound never plays with nothing visible to explain it.
        let lead: CGFloat = 90
        let monsterNear = monsters.contains {
            !$0.isDead &&
            $0.position.y > cam.position.y - half - 40 &&
            $0.position.y < cam.position.y + half + lead
        }
        if monsterNear { SoundFactory.shared.start(.monster) }
        else { SoundFactory.shared.stop(.monster) }

        let ufoNear = ufos.contains {
            !$0.isDead &&
            $0.position.y > cam.position.y - half - 40 &&
            $0.position.y < cam.position.y + half + lead
        }
        if ufoNear { SoundFactory.shared.start(.ufo) }
        else { SoundFactory.shared.stop(.ufo) }
    }

    private func scrollBackground() {
        // leapfrog the three tiles so paper always covers the view
        let camBottom = cam.position.y - size.height
        for tile in backgroundTiles {
            if tile.position.y + backgroundTileHeight < camBottom {
                tile.position.y += backgroundTileHeight * CGFloat(backgroundTiles.count)
            }
        }
    }

    // MARK: - game over

    private func finishRun() {
        guard state != .finished else { return }
        state = .finished
        SoundFactory.shared.stopAllLoops()
        TiltInput.shared.stop()
        Stats.recordRun(score: score)
        let over = GameOverScene(size: size, score: score)
        over.scaleMode = scaleMode
        view?.presentScene(over, transition: .fade(with: ArtFactory.paper, duration: 0.5))
    }
}
