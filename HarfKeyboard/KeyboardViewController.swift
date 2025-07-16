import UIKit
import SwiftUI

class KeyboardViewController: UIInputViewController {
    private var hostingController: UIHostingController<GameView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        let gameView = GameView()
        let hostingController = UIHostingController(rootView: gameView)
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingController.didMove(toParent: self)
        self.hostingController = hostingController
    }
} 