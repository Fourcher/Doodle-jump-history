import SpriteKit
import UIKit

/// The torn-paper end card. Everything lives on the card — the knocked-out
/// hero, the run's score, your best, where this run landed on the board,
/// and both buttons — so there is no floating text and no dead space.
final class GameOverScene: SKScene {

    private let finalScore: Int
    private let wasNewBest: Bool
    private var rank: Int?
    /// Buttons live on the card, so hit tests happen in the card's space.
    private weak var card: SKSpriteNode?

    init(size: CGSize, score: Int) {
        finalScore = score
        wasNewBest = ScoreStore.isNewBest(score)
        super.init(size: size)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    override func didMove(to view: SKView) {
        backgroundColor = ArtFactory.paper

        // Record the run first so the board below can show where it placed.
        if finalScore > 0 {
            rank = ScoreStore.submit(score: finalScore)
        }

        let cell: CGFloat = 32
        let bgHeight = ceil(size.height / cell) * cell
        let bg = SKSpriteNode(texture: ArtFactory.backgroundTile(
            size: CGSize(width: size.width, height: bgHeight)))
        bg.anchorPoint = .zero
        bg.zPosition = -100
        addChild(bg)

        // Card sized to its contents, and never taller than the screen allows.
        let cardWidth: CGFloat = 276
        let cardHeight = min(392, size.height - 110)
        let panel = SKSpriteNode(texture: ArtFactory.tornPanel(
            size: CGSize(width: cardWidth, height: cardHeight)))
        panel.position = CGPoint(x: size.width / 2, y: size.height * 0.54)
        panel.zRotation = -0.015
        addChild(panel)
        card = panel

        let half = cardHeight / 2
        // Fractions of the card, so the layout holds on a short screen too.
        func y(_ fraction: CGFloat) -> CGFloat { half * fraction }

        add(to: panel, text: "game over!", size: 34, y: y(0.79),
            color: UIColor(red: 0.75, green: 0.22, blue: 0.18, alpha: 1),
            bold: true, rotation: 0.03)

        // The thing there is to look at.
        let doodler = SKSpriteNode(texture: ArtFactory.heroTumbled)
        doodler.position = CGPoint(x: 0, y: y(0.50))
        doodler.zRotation = 0.22
        panel.addChild(doodler)
        doodler.run(.repeatForever(.sequence([
            .rotate(toAngle: 0.30, duration: 1.4),
            .rotate(toAngle: 0.14, duration: 1.4),
        ])))

        add(to: panel, text: "your score", size: 15, y: y(0.25),
            color: UIColor(white: 0.42, alpha: 1), bold: false)
        add(to: panel, text: "\(finalScore)", size: 46, y: y(0.07),
            color: ArtFactory.ink, bold: true)

        let bestScore = max(ScoreStore.best?.score ?? 0, finalScore)
        let bestLine = add(to: panel,
                           text: wasNewBest ? "new best!" : "best  \(bestScore)",
                           size: 18, y: y(-0.11),
                           color: wasNewBest
                               ? UIColor(red: 0.45, green: 0.60, blue: 0.16, alpha: 1)
                               : UIColor(white: 0.42, alpha: 1),
                           bold: wasNewBest)
        if wasNewBest {
            bestLine.run(.repeatForever(.sequence([
                .scale(to: 1.12, duration: 0.45), .scale(to: 1.0, duration: 0.45),
            ])))
        }

        let rule = SKSpriteNode(texture: ArtFactory.dashRule(width: cardWidth - 70))
        rule.position = CGPoint(x: 0, y: y(-0.21))
        panel.addChild(rule)

        addBoard(to: panel, topY: y(-0.30), cardWidth: cardWidth)

        addButton(to: panel, text: "play again", name: "again",
                  size: 27, y: y(-0.74))
        addButton(to: panel, text: "menu", name: "menu",
                  size: 21, y: y(-0.90))
    }

    /// Top three runs, with this one called out if it placed.
    private func addBoard(to panel: SKNode, topY: CGFloat, cardWidth: CGFloat) {
        let entries = Array(ScoreStore.entries.prefix(3))
        guard !entries.isEmpty else { return }

        let inset = cardWidth / 2 - 44
        for (i, entry) in entries.enumerated() {
            let rowY = topY - CGFloat(i) * 19
            // Highlight the row this run just earned.
            let isThisRun = (rank == i + 1)
            let color = isThisRun
                ? UIColor(red: 0.75, green: 0.22, blue: 0.18, alpha: 1)
                : UIColor(white: 0.45, alpha: 1)

            let place = SKLabelNode(fontNamed: "MarkerFelt-Thin")
            place.text = "\(i + 1)."
            place.fontSize = 15
            place.fontColor = color
            place.horizontalAlignmentMode = .left
            place.verticalAlignmentMode = .center
            place.position = CGPoint(x: -inset, y: rowY)
            panel.addChild(place)

            let value = SKLabelNode(fontNamed: isThisRun ? "MarkerFelt-Wide" : "MarkerFelt-Thin")
            value.text = "\(entry.score)"
            value.fontSize = 15
            value.fontColor = color
            value.horizontalAlignmentMode = .right
            value.verticalAlignmentMode = .center
            value.position = CGPoint(x: inset, y: rowY)
            panel.addChild(value)
        }
    }

    @discardableResult
    private func add(to panel: SKNode, text: String, size fontSize: CGFloat,
                     y: CGFloat, color: UIColor, bold: Bool,
                     rotation: CGFloat = 0) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: bold ? "MarkerFelt-Wide" : "MarkerFelt-Thin")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: y)
        label.zRotation = rotation
        panel.addChild(label)
        return label
    }

    private func addButton(to panel: SKNode, text: String, name: String,
                           size fontSize: CGFloat, y: CGFloat) {
        let label = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = ArtFactory.ink
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: y)
        label.name = name
        panel.addChild(label)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let card else { return }
        // A label's accumulated frame is expressed in its parent's space, so
        // the touch has to be converted into the card's space to match — the
        // card is offset and slightly rotated.
        let pointOnCard = convert(touch.location(in: self), to: card)

        for name in ["again", "menu"] {
            guard let node = card.childNode(withName: name) else { continue }
            // Generous target around the scribbled word.
            let target = node.calculateAccumulatedFrame().insetBy(dx: -34, dy: -13)
            guard target.contains(pointOnCard) else { continue }
            SoundFactory.shared.play(.button)
            let next: SKScene = name == "again"
                ? GameScene(size: size)
                : MenuScene(size: size)
            next.scaleMode = scaleMode
            view?.presentScene(next, transition: .fade(with: ArtFactory.paper,
                                                       duration: 0.4))
            return
        }
    }
}
