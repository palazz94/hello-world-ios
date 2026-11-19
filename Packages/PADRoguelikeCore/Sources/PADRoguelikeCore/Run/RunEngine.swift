import Foundation

public enum RunError: Error, Equatable, Sendable {
    case wrongPhase, invalidChoice, notEnoughGold
}

/// Drives a run: walk the map one node at a time (fights, events, shops, rest sites, treasure) up to the boss.
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
        let map = rules.makeMap(rng: &rng)
        state = RunState(seed: seed, rng: rng, map: map, characterID: characterID)
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

    public var map: RunMap { state.map }
    public var currentNode: MapNode? { state.currentNodeID.flatMap(map.node) }

    /// Nodes that can be entered now: the whole first row at the start, then the current node's successors.
    public var reachableNodes: [MapNode] {
        guard state.phase == .map else { return [] }
        guard let currentNode else { return map.nodes(inRow: 0) }
        return currentNode.next.compactMap(map.node)
    }

    public var currentEvent: RunEvent? {
        if case let .event(id) = state.phase { catalog.event(id: id) } else { nil }
    }

    public var relics: [Relic] { state.relicIDs.compactMap(catalog.relic(id:)) }
    /// Relics first, then affinity and talents; the resolver result does not depend on this order.
    public var modifierSources: [ModifierSource] {
        relics.map(\.source) + character.modifierSources(at: state.characterLevel)
    }

    public var resolver: ModifierResolver { ModifierResolver(sources: modifierSources) }

    public func makePlayer() -> Player {
        character.makePlayer(level: state.characterLevel, resolver: resolver, missingHP: state.missingHP)
    }

    // MARK: - Map

    public func travel(to nodeID: Int) throws(RunError) {
        guard state.phase == .map else { throw .wrongPhase }
        guard let node = reachableNodes.first(where: { $0.id == nodeID }) else { throw .invalidChoice }
        state.currentNodeID = node.id
        state.path.append(node.id)

        switch node.kind {
        case .combat, .elite, .boss:
            startFight(node.kind)
        case .rest:
            state.phase = .resting
        case .treasure:
            offerRewards(after: .treasure)
        case .shop:
            let snapshot = state
            state.phase = .shop(withRNG { rules.shop(state: snapshot, catalog: catalog, rng: &$0) })
        case .event:
            let snapshot = state
            let event = withRNG { rules.event(state: snapshot, catalog: catalog, rng: &$0) }
            state.seenEventIDs.append(event.id)
            state.phase = .event(id: event.id)
        }
    }

    // MARK: - Fights

    public func makeBattle() throws(RunError) -> BattleEngine {
        guard case let .inCombat(encounter) = state.phase else { throw .wrongPhase }
        return BattleEngine(player: makePlayer(), enemies: encounter.enemies, mode: encounter.mode,
                            modifiers: modifierSources, abilities: character.abilityStates)
    }

    /// HP carries over; a victory grants gold and rewards, or wins the run after the boss.
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
            if encounter.kind == .boss {
                state.phase = .won
            } else {
                state.gold += withRNG { rules.gold(after: encounter.kind, rng: &$0) }
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
        state.phase = .map
    }

    // MARK: - Rooms

    public func chooseEventOption(_ index: Int) throws(RunError) {
        guard let event = currentEvent else { throw .wrongPhase }
        guard event.options.indices.contains(index) else { throw .invalidChoice }
        let option = event.options[index]
        guard state.gold >= option.goldCost else { throw .notEnoughGold }

        for effect in option.effects {
            switch effect {
            case let .loseHP(fraction):
                let maxHP = makePlayer().maxHP
                state.missingHP = min(maxHP - 1, state.missingHP + Int((Double(maxHP) * fraction).rounded()))
            case let .heal(fraction):
                heal(fraction: fraction)
            case let .gainGold(amount):
                state.gold += amount
            case let .loseGold(amount):
                state.gold = max(0, state.gold - amount)
            case let .gainRelic(rarity):
                grantRandomRelic(minRarity: rarity)
            case .levelUp:
                levelUp()
            case let .fight(kind):
                startFight(kind == .elite ? .elite : .combat)
                return
            }
        }
        state.phase = .map
    }

    public func buy(_ index: Int) throws(RunError) {
        guard case var .shop(items) = state.phase else { throw .wrongPhase }
        guard items.indices.contains(index), !items[index].sold else { throw .invalidChoice }
        guard state.gold >= items[index].price else { throw .notEnoughGold }
        state.gold -= items[index].price
        apply(items[index].reward)
        items[index].sold = true
        state.phase = .shop(items)
    }

    public func leaveShop() throws(RunError) {
        guard case .shop = state.phase else { throw .wrongPhase }
        state.phase = .map
    }

    public func rest(_ option: RestOption) throws(RunError) {
        guard state.phase == .resting else { throw .wrongPhase }
        switch option {
        case .heal:
            heal(fraction: rules.restHealFraction)
        case .train:
            guard state.characterLevel < CharacterDefinition.maxLevel else { throw .invalidChoice }
            levelUp()
        }
        state.phase = .map
    }

    // MARK: - Private

    private func startFight(_ kind: NodeKind) {
        let row = max(state.row, 0)
        state.phase = .inCombat(withRNG { rules.encounter(row: row, kind: kind, catalog: catalog, rng: &$0) })
    }

    private func apply(_ reward: Reward) {
        switch reward {
        case let .relic(id):
            if !state.relicIDs.contains(id) { state.relicIDs.append(id) }
        case .levelUp:
            levelUp()
        case let .heal(fraction):
            heal(fraction: fraction)
        case let .gold(amount):
            state.gold += amount
        }
    }

    private func levelUp() {
        state.characterLevel = min(state.characterLevel + 1, CharacterDefinition.maxLevel)
    }

    private func heal(fraction: Double) {
        let amount = Int((Double(makePlayer().maxHP) * fraction).rounded())
        state.missingHP = max(0, state.missingHP - amount)
    }

    /// Falls back to 50 gold when every relic is owned.
    private func grantRandomRelic(minRarity: Rarity) {
        let unowned = catalog.relics.filter { !state.relicIDs.contains($0.id) }
        let preferred = unowned.filter { $0.rarity >= minRarity }
        let pool = preferred.isEmpty ? unowned : preferred
        guard !pool.isEmpty else {
            state.gold += 50
            return
        }
        let relic = withRNG { pool[Int.random(in: pool.indices, using: &$0)] }
        state.relicIDs.append(relic.id)
    }

    private func offerRewards(after kind: NodeKind) {
        let snapshot = state
        let rewards = withRNG { rules.rewards(after: kind, state: snapshot, catalog: catalog, rng: &$0) }
        state.phase = rewards.isEmpty ? .map : .choosingReward(rewards)
    }

    /// Draws from the saved generator without overlapping access to `state`.
    private func withRNG<T>(_ body: (inout SeededRandom) -> T) -> T {
        var rng = state.rng
        let result = body(&rng)
        state.rng = rng
        return result
    }
}
