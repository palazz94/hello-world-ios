import PADRoguelikeCore
import SwiftUI

@main
struct PadLiteApp: App {
    @State private var progress = GameProgress()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(progress)
        }
    }
}

/// Shows the menu, or the battle of the chosen level until it ends or is abandoned.
private struct RootView: View {
    @Environment(GameProgress.self) private var progress
    @State private var activeLevel: Level?

    var body: some View {
        if let level = activeLevel {
            GameView(level: level, player: progress.player, settings: progress.settings) { outcome in
                progress.record(outcome, for: level)
                activeLevel = nil
            }
            .ignoresSafeArea()
            .defersSystemGestures(on: .bottom)
            .persistentSystemOverlays(.hidden)
            .overlay(alignment: .topTrailing) {
                Button {
                    activeLevel = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal)
            }
        } else {
            MainMenuView { activeLevel = $0 }
        }
    }
}
