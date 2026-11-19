import PADRoguelikeCore
import SwiftUI

struct MainMenuView: View {
    @Environment(GameProgress.self) private var progress
    let onContinue: () -> Void
    let onStartRun: (String) -> Void
    @State private var float = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 18) {
                    Spacer()
                    HStack(spacing: -6) {
                        ForEach(Array(OrbType.allCases.enumerated()), id: \.offset) { index, type in
                            OrbImage(type: type, size: 54)
                                .offset(y: float ? (index.isMultiple(of: 2) ? -8 : 8) : 0)
                        }
                    }
                    Text("PAD-lite")
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .italic()
                        .foregroundStyle(LinearGradient(colors: [.white, Theme.gold], startPoint: .top, endPoint: .bottom))
                        .shadow(color: Theme.accent, radius: 16)
                    Text("Un roguelike di sfere e combo")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    VStack(spacing: 12) {
                        if let run = progress.run, let state = progress.runState {
                            Button(action: onContinue) {
                                HStack(spacing: 10) {
                                    HeroPortrait(character: run.character, size: 30)
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text("Continua")
                                        Text("\(run.character.name) · Lv \(state.characterLevel) · Piano \(max(state.row + 1, 0))/\(state.map.rowCount)")
                                            .font(.caption)
                                            .opacity(0.8)
                                    }
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle(color: Theme.gold))
                        }
                        NavigationLink { CharacterSelectView(onStart: onStartRun) } label: {
                            Label("Nuova run", systemImage: "sparkles")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        NavigationLink { OptionsView() } label: {
                            Label("Opzioni", systemImage: "gearshape.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle(color: .gray))
                    }
                    .frame(maxWidth: 320)
                    Spacer()
                }
                .padding()
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { float = true }
            }
        }
        .preferredColorScheme(.dark)
    }
}
