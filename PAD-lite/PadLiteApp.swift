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

/// Main menu, run screen, or the current battle (full screen) until it ends or is abandoned.
private struct RootView: View {
    @Environment(GameProgress.self) private var progress
    @State private var showingRun = false
    @State private var activeBattle: BattleEngine?

    var body: some View {
        if let battle = activeBattle {
            GameView(battle: battle, settings: progress.settings) { _ in
                progress.finishBattle(battle)
                activeBattle = nil
            }
            .ignoresSafeArea()
            .defersSystemGestures(on: .bottom)
            .persistentSystemOverlays(.hidden)
            .overlay(alignment: .topTrailing) {
                // Leaving keeps the run on this encounter; the fight restarts next time.
                Button {
                    activeBattle = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal)
            }
        } else if showingRun, progress.runState != nil {
            RunView(onBattle: { activeBattle = progress.makeBattle() },
                    onMenu: { showingRun = false })
        } else {
            MainMenuView(onContinue: { showingRun = true },
                         onStartRun: { characterID in
                             progress.startRun(characterID: characterID)
                             showingRun = true
                         })
        }
    }
}
