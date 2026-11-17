import SwiftUI
import SpriteKit

@main
struct HelloWorldApp: App {
    // @State: SwiftUI conserva la STESSA scena tra un ridisegno e l'altro (non la ricrea).
    // La dimensione iniziale è indicativa: con .resizeFill si adatta alla view.
    @State private var scene = GameScene(size: CGSize(width: 390, height: 844))

    var body: some Scene {
        WindowGroup {
            SpriteView(scene: scene)
                .background(Color(uiColor: GameScene.backgroundTint).ignoresSafeArea())
        }
    }
}
