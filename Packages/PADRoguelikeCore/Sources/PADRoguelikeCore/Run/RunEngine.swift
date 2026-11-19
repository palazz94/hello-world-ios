import Foundation

public enum RunError: Error, Equatable, Sendable {
    case wrongPhase, invalidChoice
}

/// Drives a run: pick a node per floor, fight, pick a reward, repeat until the boss falls or the hero does.
/// All state lives in `state`, so a run can be saved and restored at any phase.
public final class RunEngine {
    public private(set) var state: RunState
    public let character: CharacterDefinition
    public let rules: any RunRules
    public let catalog: GameCatalog

    public init(seed: UInt64, characterID: String, rules: any RunRules = StandardRunRules(),
                catalog: GameCatalog = .standard) {
        guard let character = catalog.character(id: characterID) else {
            preconditionFailure("Unknown character \(characterID)")
        }
        var rng = SeededRandom(seed: seed)
        let choices = rules.nodeChoices(floor: 0, rng: &rng)
        state = RunState(seed: seed, rng: rng, phase: .choosingNode(choices), characterID: characterID)
        self.character = character
        self.rules = rules
        self.catalog = catalog
    }

    public init(restoring state: RunState, rules: any RunRules = StandardRunRules(), catalog: GameCatalog = .standard) {
        guard let character = catalog.character(id: state.characterID) else {
            preconditionFailure("Unknown character \(state.characterID)")
        }
        self.state = state
        self.character = character
        self.rules = rules
        self.catalog = catalog
    }

    // MARK: - Derived

    public var relics: [Relic] { state.relicIDs.compactMap(catalog.relic(id:)) }
    /// Relics first, then affinity and talents; the resolver result does not depend on this order.
    public var modifierSources: [ModifierSource] {
        relics.map(\.source) + character.modifierSources(at: state.characterLevel)
    }

    public func makePlayer() -> Player {
        character.makePlayer(level: state.characterLevel, resolver: ModifierResolver(sources: modifierSources),
                             missingHP: state.missingHP)
    }

    // MARK: - Actions

    public func chooseNode(_ index: Int) throws(RunError) {
        guard case let .choosingNode(choices) = state.phase else { throw .wrongPhase }
        guard choices.indices.contains(index) else { throw .invalidChoice }
        let kind = choices[index]
        state.visited.append(kind)

        switch kind {
        case .combat, .elite, .boss:
            let floor = state.floor
            state.phase = .inCombat(withRNG { rules.encounter(floor: floor, kind: kind, catalog: catalog, rng: &$0) })
        case .rest:
            heal(fraction: rules.restHealFraction)
            advance()
        case .treasure:
            offerRewards(after: .treasure)
        }
    }

    public func makeBattle() throws(RunError) -> BattleEngine {
        guard case let .inCombat(encounter) = state.phase else { throw .wrongPhase }
        return BattleEngine(player: makePlayer(), enemies: encounter.enemies, mode: encounter.mode,
                            modifiers: modifierSources, abilities: character.abilityStates)
    }

    /// HP carries over; a victory leads to rewards, or wins the run after the boss.
    public func finishBattle(_ battle: BattleEngine) throws(RunError) {
        guard case let .inCombat(encounter) = state.phase else { throw .wrongPhase }
        switch battle.outcome {
        case .ongoing:
            throw .wrongPhase
        case .defeat:
            state.missingHP = battle.player.maxHP
            state.phase = .lost
        case .victory:
            state.missingHP = battle.player.maxHP - battle.player.currentHP
            if encounter.kind == .boss || state.floor >= rules.floorCount - 1 {
                state.phase = .won
            } else {
                offerRewards(after: encounter.kind)
            }
        }
    }

    /// `nil` skips the reward.
    public func chooseReward(_ index: Int?) throws(RunError) {
        guard case let .choosingReward(choices) = state.phase else { throw .wrongPhase }
        if let index {
            guard choices.indices.contains(index) else { throw .invalidChoice }
            apply(choices[index])
        }
        advance()
    }

    // MARK: - Private

    private func apply(_ reward: Reward) {
        switch reward {
        case let .relic(id):
            if !state.relicIDs.contains(id) { state.relicIDs.append(id) }
        case .levelUp:
            state.characterLevel = min(state.characterLevel + 1, CharacterDefinition.maxLevel)
        case let .heal(fraction):
            heal(fraction: fraction)
        }
    }

    private func heal(fraction: Double) {
        let amount = Int((Double(makePlayer().maxHP) * fraction).rounded())
        state.missingHP = max(0, state.missingHP - amount)
    }

    private func offerRewards(after kind: NodeKind) {
        let snapshot = state
        let rewards = withRNG { rules.rewards(after: kind, floor: snapshot.floor, state: snapshot, catalog: catalog, rng: &$0) }
        if rewards.isEmpty {
            advance()
        } else {
            state.phase = .choosingReward(rewards)
        }
    }

    private func advance() {
        state.floor += 1
        if state.floor >= rules.floorCount {
            state.phase = .won
        } else {
            let floor = state.floor
            state.phase = .choosingNode(withRNG { rules.nodeChoices(floor: floor, rng: &$0) })
        }
    }

    /// Draws from the saved generator without overlapping access to `state`.
    private func withRNG<T>(_ body: (inout SeededRandom) -> T) -> T {
        var rng = state.rng
        let result = body(&rng)
        state.rng = rng
        return result
    }
}
