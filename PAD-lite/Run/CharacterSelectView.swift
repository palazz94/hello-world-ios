import PADRoguelikeCore
import SwiftUI

struct CharacterSelectView: View {
    @Environment(GameProgress.self) private var progress
    let onStart: (String) -> Void
    @State private var pending: CharacterDefinition?

    var body: some View {
        List(CharacterDefinition.standard) { character in
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Circle().fill(character.element.color).frame(width: 16, height: 16)
                        Text(character.name).font(.headline)
                        Text(character.element.displayName).foregroundStyle(.secondary)
                    }
                    Text("HP \(character.baseHP) · Attacco \(character.baseAttack) · Cura \(character.baseRecovery)")
                        .font(.caption)
                        .monospacedDigit()
                    ForEach(character.talents) { talent in
                        Text("Lv \(talent.unlockLevel) · \(talent.name): "
                             + talent.modifiers.map(\.displayText).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(character.abilities) { ability in
                        Text("\(ability.name): \(ability.summary)")
                            .font(.caption)
                    }
                }
                Button("Gioca con \(character.name)") {
                    if progress.runState == nil {
                        onStart(character.id)
                    } else {
                        pending = character
                    }
                }
            }
        }
        .navigationTitle("Personaggio")
        .confirmationDialog("Iniziare una nuova run?",
                            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                            presenting: pending) { character in
            Button("Nuova run con \(character.name)", role: .destructive) { onStart(character.id) }
        } message: { _ in
            Text("La run in corso andrà persa.")
        }
    }
}
