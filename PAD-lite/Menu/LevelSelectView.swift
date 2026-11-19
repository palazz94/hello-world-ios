import PADRoguelikeCore
import SwiftUI

struct LevelSelectView: View {
    @Environment(GameProgress.self) private var progress
    let onPlay: (Level) -> Void

    var body: some View {
        List(Level.campaign) { level in
            let unlocked = progress.isUnlocked(level)
            Button { onPlay(level) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(level.name).font(.headline)
                        Text(level.enemies.map(\.name).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if progress.completedLevels.contains(level.id) {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    } else if !unlocked {
                        Image(systemName: "lock.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(!unlocked)
        }
        .navigationTitle("Livelli")
    }
}
