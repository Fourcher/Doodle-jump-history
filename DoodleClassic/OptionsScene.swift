import SpriteKit
import UIKit

/// The classic options menu, faithfully small: sound on/off, the
/// directional-shooting toggle (off = the launch build's straight-up
/// shots), and tilt calibration.
final class OptionsScene: SKScene {

    private var soundLabel: SKLabelNode!
    private var aimLabel: SKLabelNode!

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
        title.text = "options"
        title.fontSize = 34
        title.fontColor = ArtFactory.ink
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.82)
        title.zRotation = 0.03
        addChild(title)

        soundLabel = addRow(text: soundText(), name: "sound", y: size.height * 0.62)
        aimLabel = addRow(text: aimText(), name: "aim", y: size.height * 0.62 - 52)
        _ = addRow(text: "calibrate tilt", name: "calibrate", y: size.height * 0.62 - 104)

        let hint = SKLabelNode(fontNamed: "MarkerFelt-Thin")
        hint.text = "hold the phone how you like, then tap calibrate"
        hint.fontSize = 12
        hint.fontColor = UIColor(white: 0.5, alpha: 1)
        hint.position = CGPoint(x: size.width / 2, y: size.height * 0.62 - 130)
        addChild(hint)

        _ = addRow(text: "back", name: "back", y: size.height * 0.16)

        TiltInput.shared.start()
    }

    override func willMove(from view: SKView) {
        TiltInput.shared.stop()
    }

    private func soundText() -> String {
        SoundFactory.shared.enabled ? "sound: on" : "sound: off"
    }

    private func aimText() -> String {
        Settings.directionalShooting ? "directional shooting: on"
                                     : "directional shooting: off"
    }

    @discardableResult
    private func addRow(text: String, name: String, y: CGFloat) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        label.text = text
        label.fontSize = 22
        label.fontColor = ArtFactory.ink
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: size.width / 2, y: y)
        label.name = name
        label.zRotation = CGFloat.random(in: -0.03...0.03)
        addChild(label)
        return label
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        let names = nodes(at: point).compactMap(\.name)

        if names.contains("sound") {
            SoundFactory.shared.enabled.toggle()
            SoundFactory.shared.play(.button)
            soundLabel.text = soundText()
        } else if names.contains("aim") {
            Settings.directionalShooting.toggle()
            SoundFactory.shared.play(.button)
            aimLabel.text = aimText()
        } else if names.contains("calibrate") {
            TiltInput.shared.calibrate()
            SoundFactory.shared.play(.pickup)
            let done = SKLabelNode(fontNamed: "MarkerFelt-Thin")
            done.text = "calibrated!"
            done.fontSize = 15
            done.fontColor = UIColor(red: 0.45, green: 0.60, blue: 0.16, alpha: 1)
            done.position = CGPoint(x: size.width / 2, y: size.height * 0.62 - 152)
            addChild(done)
            done.run(.sequence([.wait(forDuration: 1.0), .fadeOut(withDuration: 0.5),
                                .removeFromParent()]))
        } else if names.contains("back") {
            SoundFactory.shared.play(.button)
            let menu = MenuScene(size: size)
            menu.scaleMode = scaleMode
            view?.presentScene(menu, transition: .fade(with: ArtFactory.paper, duration: 0.4))
        }
    }
}
