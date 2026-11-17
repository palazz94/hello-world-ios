import SwiftUI

@main
struct HelloWorldApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .ignoresSafeArea()
                .defersSystemGestures(on: .bottom)
                .persistentSystemOverlays(.hidden)
        }
    }
}
