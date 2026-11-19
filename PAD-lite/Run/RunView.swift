import PADRoguelikeCore
import SwiftUI

/// Run screen between battles: character status, then node choice, encounter preview, rewards or the final result.
struct RunView: View {
    @Environment(GameProgress.self) private var progress
    let onBattle: () -> Void
    let onMenu: () -> Void

    var body: some View {
        if let run = progress.run, let state = progress.runState {
            NavigationStack {
                List {
                    Section { RunHeader(run: run, state: state) }
                    phaseSection(state.phase, run: run)
                    if !run.relics.isEmpty {
                        Section("Reliquie") {
                            ForEach(run.relics) { RelicRow(relic: $0) }
                        }
                    }
                }
                .navigationTitle("Run")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Menu", action: onMenu)
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private func phaseSection(_ phase: RunState.Phase, run: RunEngine) -> some View {
        switch phase {
        case let .choosingNode(choices):
            Section("Scegli la prossima tappa") {
                ForEach(Array(choices.enumerated()), id: \.offset) { index, kind in
                    Button { progress.chooseNode(index) } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(kind.title).font(.headline)
                                Text(kind.summary).font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: kind.symbol)
                        }
                    }
                }
            }

        case let .inCombat(encounter):
            Section(encounter.kind.title) {
                ForEach(encounter.enemies) { enemy in
                    HStack {
                        Circle().fill(enemy.element.color).frame(width: 12, height: 12)
                        Text(enemy.name)
                        Spacer()
                        Text("HP \(enemy.maxHP) · Att \(enemy.attackPower) · ogni \(enemy.turnInterval)t")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                Button("Inizia battaglia", action: onBattle)
                    .buttonStyle(.borderedProminent)
            }

        case let .choosingReward(rewards):
            Section("Scegli una ricompensa") {
                ForEach(Array(rewards.enumerated()), id: \.offset) { index, reward in
                    Button { progress.chooseReward(index) } label: {
                        RewardLabel(reward: reward, run: run)
                    }
                }
                Button("Salta", role: .cancel) { progress.chooseReward(nil) }
            }

        case .won, .lost:
            Section {
                VStack(spacing: 8) {
                    Text(phase == .won ? "VITTORIA!" : "SCONFITTA")
                        .font(.largeTitle.weight(.heavy).italic())
                        .foregroundStyle(phase == .won ? .yellow : .red)
                    Text("Piano raggiunto: \(min(run.state.floor + 1, run.rules.floorCount))/\(run.rules.floorCount)")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                Button("Torna al menu") {
                    progress.endRun()
                    onMenu()
                }
            }
        }
    }
}

private struct RunHeader: View {
    let run: RunEngine
    let state: RunState

    var body: some View {
        let player = run.makePlayer()
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(run.character.element.color).frame(width: 14, height: 14)
                Text(run.character.name).font(.title2.bold())
                Text("Lv \(state.characterLevel)").foregroundStyle(.secondary)
                Spacer()
                Text("Piano \(min(state.floor + 1, run.rules.floorCount))/\(run.rules.floorCount)")
                    .monospacedDigit()
            }
            ProgressView(value: Double(player.currentHP), total: Double(player.maxHP))
                .tint(.green)
            Text("HP \(player.currentHP) / \(player.maxHP)")
                .font(.caption)
                .monospacedDigit()
        }
    }
}

private struct RewardLabel: View {
    let reward: Reward
    let run: RunEngine

    var body: some View {
        switch reward {
        case let .relic(id):
            if let relic = run.catalog.relic(id: id) {
                RelicRow(relic: relic)
            } else {
                Text(id)
            }
        case .levelUp:
            let next = run.state.characterLevel + 1
            let unlocked = run.character.talents.filter { $0.unlockLevel == next }.map(\.name)
            VStack(alignment: .leading, spacing: 2) {
                Text("Livello \(next)").font(.headline)
                Text("+10% a HP, attacco e cura" + (unlocked.isEmpty ? "" : " · sblocca " + unlocked.joined(separator: ", ")))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case let .heal(fraction):
            VStack(alignment: .leading, spacing: 2) {
                Text("Cura").font(.headline)
                Text("Recuperi il \(Int((fraction * 100).rounded()))% degli HP")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct RelicRow: View {
    let relic: Relic

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(relic.name).font(.headline)
                Spacer()
                Text(relic.rarity.title)
                    .font(.caption2.bold())
                    .foregroundStyle(relic.rarity.color)
            }
            Text(relic.modifiers.map(\.displayText).joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
