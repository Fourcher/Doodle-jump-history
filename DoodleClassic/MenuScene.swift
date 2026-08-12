import SpriteKit
import UIKit

/// Hand-drawn main menu: title inked on the paper, the hero bouncing on a
/// platform in the corner, scribbled text buttons — no boxes, just words,
/// the way the era drew its menus.
final class MenuScene: SKScene {

    override func didMove(to view: SKView) {
        backgroundColor = ArtFactory.paper

        let cell: CGFloat = 32
        let bgHeight = ceil(size.height / cell) * cell
        let bg = SKSpriteNode(texture: ArtFactory.backgroundTile(
            size: CGSize(width: size.width, height: bgHeight)))
        bg.anchorPoint = .zero
        bg.position = .zero
        bg.zPosition = -100
        addChild(bg)

        let title1 = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        title1.text = "Doodle"
        title1.fontSize = 52
        title1.fontColor = ArtFactory.ink
        title1.position = CGPoint(x: size.width / 2, y: size.height * 0.80)
        title1.zRotation = 0.04
        addChild(title1)

        let title2 = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        title2.text = "Classic"
        title2.fontSize = 52
        title2.fontColor = UIColor(red: 0.45, green: 0.60, blue: 0.16, alpha: 1)
        title2.position = CGPoint(x: size.width / 2, y: size.height * 0.80 - 54)
        title2.zRotation = -0.03
        addChild(title2)

        let subtitle = SKLabelNode(fontNamed: "MarkerFelt-Thin")
        subtitle.text = "a 2009 time capsule"
        subtitle.fontSize = 15
        subtitle.fontColor = UIColor(white: 0.45, alpha: 1)
        subtitle.position = CGPoint(x: size.width / 2, y: size.height * 0.80 - 86)
        addChild(subtitle)

        addButton(text: "play", name: "play", y: size.height * 0.50, size: 34)
        addButton(text: "scores", name: "scores", y: size.height * 0.50 - 56, size: 26)
        addButton(text: "options", name: "options", y: size.height * 0.50 - 104, size: 26)

        if let best = ScoreStore.best {
            let bestLabel = SKLabelNode(fontNamed: "MarkerFelt-Thin")
            bestLabel.text = "best: \(best.score) — \(best.name)"
            bestLabel.fontSize = 15
            bestLabel.fontColor = ArtFactory.ink
            bestLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.50 - 150)
            addChild(bestLabel)
        }

        // the hero, bouncing forever on a lone platform
        let platform = SKSpriteNode(texture: ArtFactory.platformGreenTex)
        platform.position = CGPoint(x: size.width * 0.72, y: size.height * 0.14)
        addChild(platform)

        let hero = SKSpriteNode(texture: ArtFactory.heroSide)
        let restY = platform.position.y + Tuning.platformSize.height / 2 + 21
        hero.position = CGPoint(x: platform.position.x, y: restY)
        addChild(hero)
        let up = SKAction.moveBy(x: 0, y: 90, duration: 0.55)
        up.timingMode = .easeOut
        let down = SKAction.moveBy(x: 0, y: -90, duration: 0.55)
        down.timingMode = .easeIn
        let bounceSound = SKAction.run { SoundFactory.shared.play(.bounce) }
        hero.run(.repeatForever(.sequence([bounceSound, up, down])))
    }

    private func addButton(text: String, name: String, y: CGFloat, size fontSize: CGFloat) {
        let label = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = ArtFactory.ink
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: size.width / 2, y: y)
        label.name = name
        label.zRotation = CGFloat.random(in: -0.04...0.04)
        addChild(label)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        // generous tap targets around the scribbled words
        for name in ["play", "scores", "options"] {
            if let node = childNode(withName: name),
               node.calculateAccumulatedFrame().insetBy(dx: -30, dy: -14).contains(point) {
                activate(name)
                return
            }
        }
    }

    private func activate(_ name: String) {
        SoundFactory.shared.play(.button)
        switch name {
        case "play":
            let game = GameScene(size: size)
            game.scaleMode = scaleMode
            view?.presentScene(game, transition: .fade(with: ArtFactory.paper, duration: 0.4))
        case "scores":
            let scores = ScoresScene(size: size)
            scores.scaleMode = scaleMode
            view?.presentScene(scores, transition: .fade(with: ArtFactory.paper, duration: 0.4))
        case "options":
            let options = OptionsScene(size: size)
            options.scaleMode = scaleMode
            view?.presentScene(options, transition: .fade(with: ArtFactory.paper, duration: 0.4))
        default:
            break
        }
    }
}

/// The local top ten plus the classic stats block, written out like a
/// score sheet.
final class ScoresScene: SKScene {

    override func didMove(to view: SKView) {
        backgroundColor = ArtFactory.paper

        let cell: CGFloat = 32
        let bgHeight = ceil(size.height / cell) * cell
        let bg = SKSpriteNode(texture: ArtFactory.backgroundTile(
            size: CGSize(width: size.width, height: bgHeight)))
        bg.anchorPoint = .zero
        bg.zPosition = -100
        addChild(bg)

        let title = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        title.text = "top scores"
        title.fontSize = 30
        title.fontColor = ArtFactory.ink
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.90)
        title.zRotation = 0.02
        addChild(title)

        let entries = ScoreStore.entries
        if entries.isEmpty {
            let empty = SKLabelNode(fontNamed: "MarkerFelt-Thin")
            empty.text = "no scores yet — go jump!"
            empty.fontSize = 18
            empty.fontColor = UIColor(white: 0.45, alpha: 1)
            empty.position = CGPoint(x: size.width / 2, y: size.height * 0.70)
            addChild(empty)
        }
        let rowHeight = min(30, size.height * 0.36 / 10)
        for (i, entry) in entries.prefix(10).enumerated() {
            let y = size.height * 0.86 - CGFloat(i + 1) * rowHeight
            addText("\(i + 1).", x: 34, y: y, align: .left, bold: true)
            addText(entry.name, x: 66, y: y, align: .left, bold: false)
            addText("\(entry.score)", x: size.width - 34, y: y, align: .right, bold: true)
        }

        // stats block
        let statsTop = size.height * 0.86 - 11 * rowHeight - 16
        let statsTitle = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        statsTitle.text = "stats"
        statsTitle.fontSize = 22
        statsTitle.fontColor = ArtFactory.ink
        statsTitle.position = CGPoint(x: size.width / 2, y: statsTop)
        statsTitle.zRotation = -0.02
        addChild(statsTitle)

        let stats: [(String, String)] = [
            ("games played", "\(Stats.gamesPlayed)"),
            ("average score", "\(Stats.averageScore)"),
            ("total jumps", "\(Stats.totalJumps)"),
            ("jetpack flights", "\(Stats.jetpackFlights)"),
            ("propeller flights", "\(Stats.propellerFlights)"),
            ("UFOs shot down", "\(Stats.ufosShot)"),
        ]
        for (i, stat) in stats.enumerated() {
            let y = statsTop - 26 - CGFloat(i) * 22
            addText(stat.0, x: 44, y: y, align: .left, bold: false, small: true)
            addText(stat.1, x: size.width - 44, y: y, align: .right, bold: false, small: true)
        }

        let reset = SKLabelNode(fontNamed: "MarkerFelt-Thin")
        reset.text = "reset scores & stats"
        reset.fontSize = 14
        reset.fontColor = UIColor(red: 0.75, green: 0.25, blue: 0.2, alpha: 0.9)
        reset.position = CGPoint(x: size.width / 2, y: size.height * 0.135)
        reset.name = "reset"
        addChild(reset)

        let back = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        back.text = "back"
        back.fontSize = 24
        back.fontColor = ArtFactory.ink
        back.position = CGPoint(x: size.width / 2, y: size.height * 0.07)
        back.name = "back"
        addChild(back)
    }

    private func addText(_ text: String, x: CGFloat, y: CGFloat,
                         align: SKLabelHorizontalAlignmentMode, bold: Bool,
                         small: Bool = false) {
        let label = SKLabelNode(fontNamed: bold ? "MarkerFelt-Wide" : "MarkerFelt-Thin")
        label.text = text
        label.fontSize = small ? 15 : 18
        label.fontColor = ArtFactory.ink
        label.horizontalAlignmentMode = align
        label.position = CGPoint(x: x, y: y)
        addChild(label)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        let names = nodes(at: point).compactMap(\.name)
        if names.contains("back") {
            SoundFactory.shared.play(.button)
            let menu = MenuScene(size: size)
            menu.scaleMode = scaleMode
            view?.presentScene(menu, transition: .fade(with: ArtFactory.paper, duration: 0.4))
        } else if names.contains("reset") {
            SoundFactory.shared.play(.button)
            confirmReset()
        }
    }

    private func confirmReset() {
        let alert = UIAlertController(title: "reset everything?",
                                      message: "scores and stats will be wiped.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "reset", style: .destructive) { [weak self] _ in
            ScoreStore.wipe()
            Stats.reset()
            guard let self, let view = self.view else { return }
            let fresh = ScoresScene(size: self.size)
            fresh.scaleMode = self.scaleMode
            view.presentScene(fresh, transition: .fade(with: ArtFactory.paper, duration: 0.3))
        })
        view?.window?.rootViewController?.present(alert, animated: true)
    }
}
