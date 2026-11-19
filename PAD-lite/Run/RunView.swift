import PADRoguelikeCore
import SwiftUI

/// Run screen: status bar on top, the map below, and a panel over the map for the current room.
struct RunView: View {
    @Environment(GameProgress.self) private var progress
    let onBattle: () -> Void
    let onMenu: () -> Void
    @State private var selectedRelic: Relic?
    @State private var showingHero = false

    var body: some View {
        if let run = progress.run, let state = progress.runState {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    RunHUD(run: run, state: state, onMenu: onMenu, onHero: { showingHero = true },
                           onRelic: { selectedRelic = $0 })
                    MapView(map: state.map, path: state.path, currentID: state.currentNodeID,
                            reachable: Set(run.reachableNodes.map(\.id)),
                            onSelect: { progress.travel(to: $0) })
                }
                if state.phase != .map {
                    Color.black.opacity(0.65)
                        .ignoresSafeArea()
                        .transition(.opacity)
                    ScrollView {
                        PhasePanel(run: run, state: state, onBattle: onBattle, onMenu: onMenu)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 40)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.35), value: state.phase)
            .sheet(item: $selectedRelic) { relic in
                RelicCard(relic: relic)
                    .padding()
                    .presentationDetents([.height(220)])
                    .presentationBackground(Theme.panel)
            }
            .sheet(isPresented: $showingHero) {
                HeroSheet(character: run.character, level: state.characterLevel)
                    .presentationBackground(Theme.panel)
            }
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - HUD

private struct RunHUD: View {
    let run: RunEngine
    let state: RunState
    let onMenu: () -> Void
    let onHero: () -> Void
    let onRelic: (Relic) -> Void

    var body: some View {
        let player = run.makePlayer()
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button(action: onHero) { HeroPortrait(character: run.character, size: 52) }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(run.character.name).font(.headline)
                        Text("Lv \(state.characterLevel)")
                            .font(.caption.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.white.opacity(0.15)))
                    }
                    HPBarView(current: player.currentHP, maximum: player.maxHP)
                }
                VStack(alignment: .trailing, spacing: 6) {
                    GoldLabel(amount: state.gold)
                    Text("Piano \(max(state.row + 1, 0))/\(state.map.rowCount)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Button(action: onMenu) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title3.bold())
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.white.opacity(0.1)))
                }
                .foregroundStyle(.white)
            }
            if !run.relics.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(run.relics) { relic in
                            Button { onRelic(relic) } label: { RelicIcon(relic: relic, size: 34) }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Panels

private struct PhasePanel: View {
    let run: RunEngine
    let state: RunState
    let onBattle: () -> Void
    let onMenu: () -> Void

    var body: some View {
        switch state.phase {
        case .map:
            EmptyView()
        case let .inCombat(encounter):
            CombatPanel(encounter: encounter, onFight: onBattle)
        case let .choosingReward(rewards):
            RewardPanel(rewards: rewards, run: run)
        case .event:
            if let event = run.currentEvent { EventPanel(event: event, gold: state.gold) }
        case let .shop(items):
            ShopPanel(items: items, run: run, gold: state.gold)
        case .resting:
            RestPanel(run: run, level: state.characterLevel)
        case .won, .lost:
            EndPanel(won: state.phase == .won, run: run, state: state, onMenu: onMenu)
        }
    }
}

private struct CombatPanel: View {
    let encounter: Encounter
    let onFight: () -> Void

    var body: some View {
        PanelCard(title: encounter.kind.title, symbol: encounter.kind.symbol, color: encounter.kind.color) {
            ForEach(encounter.enemies) { enemy in
                HStack(spacing: 12) {
                    EnemyPortrait(name: enemy.name, element: enemy.element, size: 72)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(enemy.name).font(.headline)
                            Circle().fill(enemy.element.color).frame(width: 10, height: 10)
                        }
                        Text("HP \(enemy.maxHP) · Attacco \(enemy.attackPower) ogni \(enemy.turnInterval) t")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        ForEach(enemy.traits, id: \.self) { trait in
                            Text("\(trait.title): \(trait.detail)")
                                .font(.caption2.bold())
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .cardStyle(border: enemy.element.color)
            }
            Button("Combatti!", action: onFight)
                .buttonStyle(PrimaryButtonStyle(color: encounter.kind.color))
        }
    }
}

private struct RewardPanel: View {
    @Environment(GameProgress.self) private var progress
    let rewards: [Reward]
    let run: RunEngine

    var body: some View {
        PanelCard(title: "Bottino", symbol: "gift.fill", color: Theme.gold) {
            Text("Scegli una ricompensa").font(.subheadline).foregroundStyle(.secondary)
            ForEach(Array(rewards.enumerated()), id: \.offset) { index, reward in
                Button { progress.chooseReward(index) } label: { RewardCard(reward: reward, run: run) }
                    .buttonStyle(ChoiceButtonStyle())
            }
            Button("Salta") { progress.chooseReward(nil) }
                .foregroundStyle(.secondary)
        }
    }
}

private struct RewardCard: View {
    let reward: Reward
    let run: RunEngine

    var body: some View {
        switch reward {
        case let .relic(id):
            if let relic = run.catalog.relic(id: id) { RelicCard(relic: relic) }
        case .levelUp:
            let next = min(run.state.characterLevel + 1, CharacterDefinition.maxLevel)
            let unlocked = run.character.talents.filter { $0.unlockLevel == next }
            HStack(spacing: 12) {
                HeroPortrait(character: run.character, size: 50)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Livello \(next)").font(.headline)
                    Text("+10% a HP, attacco e cura").font(.caption).foregroundStyle(.secondary)
                    ForEach(unlocked) { talent in
                        Text("Sblocca \(talent.name)").font(.caption.bold()).foregroundStyle(Theme.gold)
                        ModifierList(modifiers: talent.modifiers)
                    }
                }
            }
            .cardStyle(border: Theme.gold)
        case let .heal(fraction):
            simpleCard(symbol: "heart.fill", color: .pink, title: "Cura",
                       detail: "Recuperi il \(Int((fraction * 100).rounded()))% degli HP")
        case let .gold(amount):
            simpleCard(symbol: "circle.fill", color: Theme.gold, title: "\(amount) oro", detail: "Da spendere dal mercante")
        }
    }

    private func simpleCard(symbol: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(color.gradient)
                .frame(width: 50, height: 50)
                .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .cardStyle(border: color)
    }
}

private struct EventPanel: View {
    @Environment(GameProgress.self) private var progress
    let event: RunEvent
    let gold: Int

    var body: some View {
        PanelCard(title: event.title, symbol: "questionmark", color: NodeKind.event.color) {
            Text(event.text)
                .font(.callout.italic())
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.bottom, 4)
            ForEach(Array(event.options.enumerated()), id: \.offset) { index, option in
                Button { progress.chooseEventOption(index) } label: {
                    HStack {
                        Text(option.label).font(.subheadline.bold()).multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                    .cardStyle(border: NodeKind.event.color)
                }
                .buttonStyle(ChoiceButtonStyle())
                .disabled(gold < option.goldCost)
            }
        }
    }
}

private struct ShopPanel: View {
    @Environment(GameProgress.self) private var progress
    let items: [ShopItem]
    let run: RunEngine
    let gold: Int

    var body: some View {
        PanelCard(title: "Mercante", symbol: "cart.fill", color: NodeKind.shop.color) {
            GoldLabel(amount: gold)
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                VStack(spacing: 6) {
                    RewardCard(reward: item.reward, run: run)
                    Button {
                        progress.buy(index)
                    } label: {
                        if item.sold {
                            Text("Venduto")
                        } else {
                            HStack(spacing: 6) {
                                Text("Compra")
                                GoldLabel(amount: item.price)
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(color: NodeKind.shop.color.opacity(0.8)))
                    .disabled(item.sold || gold < item.price)
                }
                .opacity(item.sold ? 0.5 : 1)
            }
            Button("Esci dal negozio") { progress.leaveShop() }
                .buttonStyle(PrimaryButtonStyle(color: .gray))
        }
    }
}

private struct RestPanel: View {
    @Environment(GameProgress.self) private var progress
    let run: RunEngine
    let level: Int

    var body: some View {
        PanelCard(title: "Accampamento", symbol: "tent.fill", color: NodeKind.rest.color) {
            Text("Il fuoco scoppietta. Come passi la notte?")
                .font(.callout.italic())
                .foregroundStyle(.white.opacity(0.85))
            Button { progress.rest(.heal) } label: {
                option(symbol: "bed.double.fill", title: "Riposa",
                       detail: "Recuperi il \(Int((run.rules.restHealFraction * 100).rounded()))% degli HP", color: .pink)
            }
            .buttonStyle(ChoiceButtonStyle())
            Button { progress.rest(.train) } label: {
                option(symbol: "figure.strengthtraining.traditional", title: "Allenati",
                       detail: level < CharacterDefinition.maxLevel ? "+1 livello" : "Sei già al livello massimo",
                       color: Theme.gold)
            }
            .buttonStyle(ChoiceButtonStyle())
            .disabled(level >= CharacterDefinition.maxLevel)
        }
    }

    private func option(symbol: String, title: String, detail: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(color.gradient)
                .frame(width: 50, height: 50)
                .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .cardStyle(border: color)
    }
}

private struct EndPanel: View {
    @Environment(GameProgress.self) private var progress
    let won: Bool
    let run: RunEngine
    let state: RunState
    let onMenu: () -> Void

    var body: some View {
        PanelCard(title: won ? "VITTORIA!" : "SCONFITTA", symbol: won ? "trophy.fill" : "xmark.octagon.fill",
                  color: won ? Theme.gold : .red) {
            HeroPortrait(character: run.character, size: 80)
            VStack(spacing: 4) {
                Text("Piano raggiunto: \(max(state.row + 1, 0))/\(state.map.rowCount)")
                Text("Livello \(state.characterLevel) · \(run.relics.count) reliquie · \(state.gold) oro")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            Button("Torna al menu") {
                progress.endRun()
                onMenu()
            }
            .buttonStyle(PrimaryButtonStyle(color: won ? Theme.gold : .red))
        }
    }
}

// MARK: - Hero details

struct HeroSheet: View {
    let character: CharacterDefinition
    let level: Int

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HeroPortrait(character: character, size: 96)
                VStack(spacing: 4) {
                    Text(character.name).font(.title.bold())
                    Text(character.title).font(.headline).foregroundStyle(character.element.color)
                    Text(character.playstyle).font(.callout).multilineTextAlignment(.center).foregroundStyle(.secondary)
                }
                Text("Livello \(level) · HP \(character.hp(at: level)) · Attacco \(character.attack(at: level)) · Cura \(character.recovery(at: level))")
                    .font(.caption)
                    .monospacedDigit()
                Text("Affinità: danno \(character.element.displayName) ×1,5").font(.caption.bold()).foregroundStyle(character.element.color)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Talenti").font(.headline)
                    ForEach(character.talents) { talent in
                        let unlocked = talent.unlockLevel <= level
                        HStack(alignment: .top) {
                            Image(systemName: unlocked ? "checkmark.seal.fill" : "lock.fill")
                                .foregroundStyle(unlocked ? Theme.gold : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(talent.name) · Lv \(talent.unlockLevel)").font(.subheadline.bold())
                                ModifierList(modifiers: talent.modifiers)
                            }
                        }
                        .opacity(unlocked ? 1 : 0.55)
                    }
                    Text("Abilità").font(.headline).padding(.top, 6)
                    ForEach(character.abilities) { ability in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ability.name).font(.subheadline.bold())
                            Text(ability.summary).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .cardStyle(border: character.element.color)
            }
            .padding(24)
        }
    }
}
