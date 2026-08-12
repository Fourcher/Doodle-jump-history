import UIKit
import SpriteKit

/// Hosts the SpriteKit view. The whole game runs in a scene whose logical
/// width is fixed at 320 points — the coordinate space of the original
/// 2009-era iPhone — with the height derived from the device's aspect
/// ratio so modern tall screens are filled edge to edge.
final class GameViewController: UIViewController {

    override func loadView() {
        view = SKView(frame: UIScreen.main.bounds)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let skView = view as? SKView else { return }

        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 60

        let aspect = skView.bounds.height / skView.bounds.width
        let sceneSize = CGSize(width: GameGeometry.worldWidth,
                               height: (GameGeometry.worldWidth * aspect).rounded())
        GameGeometry.sceneHeight = sceneSize.height

        let menu = MenuScene(size: sceneSize)
        menu.scaleMode = .aspectFill
        skView.presentScene(menu)
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
}
