import SpriteKit
import UIKit

/// The torn-paper end card: final score, best score, and the play again /
/// menu buttons. Single-player, so the run records itself — no name box.
final class GameOverScene: SKScene {

    private let finalScore: Int
    private let wasNewBest: Bool

    init(size: CGSize, score: Int) {
        finalScore = score
        wasNewBest = ScoreStore.isNewBest(score)
        super.init(size: size)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    override func didMove(to view: SKView) {
        backgroundColor = ArtFactory.paper

        let cell: CGFloat = 32
        let bgHeight = ceil(size.height / cell) * cell
        let bg = SKSpriteNode(texture: ArtFactory.backgroundTile(
            size: CGSize(width: size.width, height: bgHeight)))
        bg.anchorPoint = .zero
        bg.zPosition = -100
        addChild(bg)

        let panel = SKSpriteNode(texture: ArtFactory.tornPanel(
            size: CGSize(width: 260, height: 320)))
        panel.position = CGPoint(x: size.width / 2, y: size.height * 0.58)
        panel.zRotation = -0.02
        addChild(panel)

        let title = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        title.text = "game over!"
        title.fontSize = 36
        title.fontColor = UIColor(red: 0.75, green: 0.22, blue: 0.18, alpha: 1)
        title.position = CGPoint(x: 0, y: 100)
        title.zRotation = 0.03
        panel.addChild(title)

        let scoreCaption = SKLabelNode(fontNamed: "MarkerFelt-Thin")
        scoreCaption.text = "your score"
        scoreCaption.fontSize = 16
        scoreCaption.fontColor = UIColor(white: 0.4, alpha: 1)
        scoreCaption.position = CGPoint(x: 0, y: 58)
        panel.addChild(scoreCaption)

        let scoreLabel = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        scoreLabel.text = "\(finalScore)"
        scoreLabel.fontSize = 44
        scoreLabel.fontColor = ArtFactory.ink
        scoreLabel.position = CGPoint(x: 0, y: 14)
        panel.addChild(scoreLabel)

        let bestLabel = SKLabelNode(fontNamed: "MarkerFelt-Thin")
        let best = max(ScoreStore.best?.score ?? 0, finalScore)
        bestLabel.text = wasNewBest ? "new high score!" : "best: \(best)"
        bestLabel.fontSize = 18
        bestLabel.fontColor = wasNewBest
            ? UIColor(red: 0.45, green: 0.60, blue: 0.16, alpha: 1)
            : UIColor(white: 0.4, alpha: 1)
        bestLabel.position = CGPoint(x: 0, y: -22)
        panel.addChild(bestLabel)
        if wasNewBest {
            bestLabel.run(.repeatForever(.sequence([
                .scale(to: 1.15, duration: 0.4),
                .scale(to: 1.0, duration: 0.4),
            ])))
        }

        addButton(text: "play again", name: "again", y: size.height * 0.30)
        addButton(text: "menu", name: "menu", y: size.height * 0.30 - 56)

        if finalScore > 0 {
            ScoreStore.submit(score: finalScore)
        }
    }

    private func addButton(text: String, name: String, y: CGFloat) {
        let container = SKNode()
        container.name = name
        container.position = CGPoint(x: size.width / 2, y: y)
        let plate = SKSpriteNode(texture: ArtFactory.buttonPlate(
            size: CGSize(width: 168, height: 42), seed: 111 + UInt64(y)))
        plate.name = name
        container.addChild(plate)
        let label = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        label.text = text
        label.fontSize = 22
        label.fontColor = ArtFactory.ink
        label.verticalAlignmentMode = .center
        label.name = name
        container.addChild(label)
        addChild(container)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let names = nodes(at: touch.location(in: self)).compactMap(\.name)
        if names.contains("again") {
            SoundFactory.shared.play(.button)
            let game = GameScene(size: size)
            game.scaleMode = scaleMode
            view?.presentScene(game, transition: .fade(with: ArtFactory.paper, duration: 0.4))
        } else if names.contains("menu") {
            SoundFactory.shared.play(.button)
            let menu = MenuScene(size: size)
            menu.scaleMode = scaleMode
            view?.presentScene(menu, transition: .fade(with: ArtFactory.paper, duration: 0.4))
        }
    }
}
