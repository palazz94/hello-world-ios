import SpriteKit
import SwiftUI
import UIKit

final class GameViewController: UIViewController {

    private enum Metrics {
        static let sideMargin: CGFloat = 12
        static let bottomMargin: CGFloat = 12
        static let timerBarHeight: CGFloat = 10
        static let timerBarGap: CGFloat = 10
    }

    private let engine = BoardEngine(cols: 6, rows: 5)
    private lazy var scene = GameScene(engine: engine)

    private var appliedBounds: CGRect = .null
    private var appliedInsets: UIEdgeInsets = .zero

    private var skView: SKView { view as! SKView }

    override func loadView() {
        let skView = SKView()
        skView.ignoresSiblingOrder = true
        skView.isMultipleTouchEnabled = false
        skView.preferredFramesPerSecond = 120
        #if DEBUG
        skView.showsFPS = true
        skView.showsNodeCount = true
        #endif
        view = skView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        skView.presentScene(scene)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let maxFPS = view.window?.windowScene?.screen.maximumFramesPerSecond {
            skView.preferredFramesPerSecond = maxFPS
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bounds = view.bounds
        let insets = view.safeAreaInsets
        guard bounds.width > 0, bounds.height > 0,
              bounds != appliedBounds || insets != appliedInsets else { return }
        appliedBounds = bounds
        appliedInsets = insets

        scene.size = bounds.size
        scene.apply(layout: Self.boardLayout(for: bounds.size, safeArea: insets,
                                             cols: engine.cols, rows: engine.rows))
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .portrait }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .bottom }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    /// Fits the board inside the bottom half of the screen, limited by width on tall phones
    /// and by height on square-ish foldable displays. Returned in SpriteKit (y-up) coordinates.
    static func boardLayout(for size: CGSize, safeArea: UIEdgeInsets, cols: Int, rows: Int) -> BoardLayout {
        let safeMinX = safeArea.left + Metrics.sideMargin
        let availableWidth = size.width - safeArea.left - safeArea.right - Metrics.sideMargin * 2
        let bottomHalfHeight = size.height / 2 - safeArea.bottom - Metrics.bottomMargin
        let availableHeight = bottomHalfHeight - Metrics.timerBarHeight - Metrics.timerBarGap

        let cell = max(1, floor(min(availableWidth / CGFloat(cols), availableHeight / CGFloat(rows))))
        let boardWidth = cell * CGFloat(cols)

        return BoardLayout(
            origin: CGPoint(x: (safeMinX + (availableWidth - boardWidth) / 2).rounded(),
                            y: safeArea.bottom + Metrics.bottomMargin),
            cellSize: cell,
            timerBarHeight: Metrics.timerBarHeight,
            timerBarGap: Metrics.timerBarGap
        )
    }
}

/// SwiftUI bridge for the `App` lifecycle.
struct GameView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> GameViewController { GameViewController() }
    func updateUIViewController(_ uiViewController: GameViewController, context: Context) {}
}
