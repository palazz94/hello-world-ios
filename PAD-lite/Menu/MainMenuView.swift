import PADRoguelikeCore
import SwiftUI

struct MainMenuView: View {
    @Environment(GameProgress.self) private var progress
    let onContinue: () -> Void
    let onStartRun: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                Text("PAD-lite")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .italic()
                Spacer()
                if let run = progress.run, let state = progress.runState {
                    Button(action: onContinue) {
                        menuLabel("Continua", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    Text("\(run.character.name) · Lv \(state.characterLevel) · Piano \(min(state.floor + 1, run.rules.floorCount))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                menuLink("Nuova run", systemImage: "sparkles") { CharacterSelectView(onStart: onStartRun) }
                menuLink("Opzioni", systemImage: "gearshape.fill") { OptionsView() }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.07, green: 0.06, blue: 0.12))
        }
        .preferredColorScheme(.dark)
    }

    private func menuLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.title3.bold())
            .frame(maxWidth: 240)
    }

    private func menuLink<Destination: View>(_ title: String, systemImage: String,
                                             @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination()) {
            menuLabel(title, systemImage: systemImage)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}
