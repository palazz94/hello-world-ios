import Foundation

/// Hooks that shape a run. Implement this to change map layout, difficulty curve or rewards
/// without touching `RunEngine`. All randomness must come from `rng` to keep runs reproducible.
public protocol RunRules: Sendable {
    var floorCount: Int { get }
    var restHealFraction: Double { get }

    func nodeChoices(floor: Int, rng: inout SeededRandom) -> [NodeKind]
    func encounter(floor: Int, kind: NodeKind, catalog: GameCatalog, rng: inout SeededRandom) -> Encounter
    func enemyHP(base: Int, floor: Int, kind: NodeKind) -> Int
    func enemyAttack(base: Int, floor: Int, kind: NodeKind) -> Int
    /// Choices offered after clearing a node; empty means no reward screen.
    func rewards(after kind: NodeKind, floor: Int, state: RunState, catalog: GameCatalog,
                 rng: inout SeededRandom) -> [Reward]
}

public struct StandardRunRules: RunRules {
    public var floorCount = 8
    public var choicesPerFloor = 3
    public var hpGrowthPerFloor = 0.2
    public var attackGrowthPerFloor = 0.12
    public var restHealFraction = 0.3
    public var rewardHealFraction = 0.3

    public init() {}

    /// Floor 0 is always a plain fight and the last floor is always the boss.
    public func nodeChoices(floor: Int, rng: inout SeededRandom) -> [NodeKind] {
        if floor >= floorCount - 1 { return [.boss] }
        if floor == 0 { return [.combat] }

        var weights: [(kind: NodeKind, weight: Int)] = [(.combat, 5), (.elite, floor >= 2 ? 2 : 0), (.rest, 2), (.treasure, 1)]
        weights.removeAll { $0.weight == 0 }
        var picks: [NodeKind] = []
        while picks.count < choicesPerFloor, !weights.isEmpty {
            var roll = Int.random(in: 0..<weights.reduce(0) { $0 + $1.weight }, using: &rng)
            for index in weights.indices {
                roll -= weights[index].weight
                if roll < 0 {
                    picks.append(weights.remove(at: index).kind)
                    break
                }
            }
        }
        return picks
    }

    public func encounter(floor: Int, kind: NodeKind, catalog: GameCatalog, rng: inout SeededRandom) -> Encounter {
        let tier: EnemyTier = switch kind {
        case .boss: .boss
        case .elite: .elite
        default: .minion
        }
        let pool = catalog.enemies.filter { $0.tier == tier }
        precondition(!pool.isEmpty, "The catalog has no \(tier) enemies")

        let count = kind == .combat ? min(3, 1 + floor / 2) : 1
        let enemies = (0..<count).map { index in
            let template = pool[Int.random(in: pool.indices, using: &rng)]
            return Enemy(id: index, name: template.name, element: template.element,
                         maxHP: enemyHP(base: template.baseHP, floor: floor, kind: kind),
                         attackPower: enemyAttack(base: template.baseAttack, floor: floor, kind: kind),
                         turnInterval: template.turnInterval)
        }
        return Encounter(kind: kind, mode: .simultaneous, enemies: enemies)
    }

    public func enemyHP(base: Int, floor: Int, kind: NodeKind) -> Int {
        max(1, Int((Double(base) * (1 + hpGrowthPerFloor * Double(floor))).rounded()))
    }

    public func enemyAttack(base: Int, floor: Int, kind: NodeKind) -> Int {
        max(0, Int((Double(base) * (1 + attackGrowthPerFloor * Double(floor))).rounded()))
    }

    /// Combat: two relics plus a level-up (or a heal at max level).
    /// Elites offer rare-or-better relics; treasure offers three relics.
    public func rewards(after kind: NodeKind, floor: Int, state: RunState, catalog: GameCatalog,
                        rng: inout SeededRandom) -> [Reward] {
        let unowned = catalog.relics.filter { !state.relicIDs.contains($0.id) }
        switch kind {
        case .rest, .boss:
            return []
        case .treasure:
            return unowned.shuffled(using: &rng).prefix(3).map { .relic(id: $0.id) }
        case .combat, .elite:
            let minRarity: Rarity = kind == .elite ? .rare : .common
            let preferred = unowned.filter { $0.rarity >= minRarity }
            var offer: [Reward] = (preferred.isEmpty ? unowned : preferred).shuffled(using: &rng).prefix(2)
                .map { .relic(id: $0.id) }
            offer.append(state.characterLevel < CharacterDefinition.maxLevel ? .levelUp : .heal(rewardHealFraction))
            return offer
        }
    }
}
