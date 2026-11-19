import PADRoguelikeCore
import SwiftUI

struct CharacterSelectView: View {
    @Environment(GameProgress.self) private var progress
    let onStart: (String) -> Void
    @State private var pending: CharacterDefinition?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(GameCatalog.standard.characters) { character in
                    HeroCard(character: character) {
                        if progress.runState == nil {
                            onStart(character.id)
                        } else {
                            pending = character
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Scegli l'eroe")
        .confirmationDialog("Iniziare una nuova run?",
                            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                            presenting: pending) { character in
            Button("Nuova run con \(character.name)", role: .destructive) { onStart(character.id) }
        } message: { _ in
            Text("La run in corso andrà persa.")
        }
    }
}

private struct HeroCard: View {
    let character: CharacterDefinition
    let onPick: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                HeroPortrait(character: character, size: 72)
                VStack(alignment: .leading, spacing: 3) {
                    Text(character.name).font(.title2.bold())
                    Text(character.title).font(.subheadline.bold()).foregroundStyle(character.element.color)
                    Text("HP \(character.baseHP) · Att \(character.baseAttack) · Cura \(character.baseRecovery)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            Text(character.playstyle).font(.callout)
            ForEach(character.talents) { talent in
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lv \(talent.unlockLevel) · \(talent.name)").font(.caption.bold())
                    ModifierList(modifiers: talent.modifiers)
                }
            }
            ForEach(character.abilities) { ability in
                Label {
                    Text("\(ability.name): \(ability.summary)")
                } icon: {
                    Image(systemName: "bolt.circle.fill")
                }
                .font(.caption)
                .foregroundStyle(Theme.gold)
            }
            Button("Gioca con \(character.name)", action: onPick)
                .buttonStyle(PrimaryButtonStyle(color: character.element.color))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.panel))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(character.element.color.opacity(0.6), lineWidth: 2))
    }
}
