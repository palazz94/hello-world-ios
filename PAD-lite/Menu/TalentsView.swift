import PADRoguelikeCore
import SwiftUI

struct TalentsView: View {
    @Environment(GameProgress.self) private var progress

    var body: some View {
        List {
            Section {
                Text("Punti disponibili: \(progress.availableTalentPoints)")
                    .font(.headline)
            } footer: {
                Text("Ottieni 1 punto per ogni livello completato.")
            }

            Section {
                ForEach(Talent.allCases, id: \.self) { talent in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(talent.displayName).font(.headline)
                            Text(talent.summary).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(progress.rank(of: talent))/\(Talent.maxRank)").monospacedDigit()
                        Button {
                            progress.upgrade(talent)
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!progress.canUpgrade(talent))
                    }
                }
            }

            Section {
                Button("Azzera talenti", role: .destructive) { progress.resetTalents() }
            }
        }
        .navigationTitle("Talenti")
    }
}

private extension Talent {
    var displayName: String {
        switch self {
        case .vitality: "Vitalità"
        case .power: "Potenza"
        case .recovery: "Rigenerazione"
        }
    }

    var summary: String {
        let percent = Int((bonusPerRank * 100).rounded())
        switch self {
        case .vitality: return "+\(percent)% HP massimi per grado"
        case .power: return "+\(percent)% attacco per grado"
        case .recovery: return "+\(percent)% cura per grado"
        }
    }
}
