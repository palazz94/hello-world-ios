import Foundation

public enum EncounterMode: Sendable {
    /// All enemies are on the field, act and can be targeted.
    case simultaneous
    /// Only the first alive enemy is active; the next one steps in when it falls.
    case sequential
}

public enum BattleOutcome: Sendable {
    case ongoing, victory, defeat
}

public struct CombatRules: Sendable {
    public var bonusPerExtraCombo: Double
    public var bonusPerExtraOrb: Double

    public init(bonusPerExtraCombo: Double = 0.25, bonusPerExtraOrb: Double = 0.25) {
        self.bonusPerExtraCombo = bonusPerExtraCombo
        self.bonusPerExtraOrb = bonusPerExtraOrb
    }

    /// 1 combo = x1, each extra combo adds `bonusPerExtraCombo`.
    public func comboMultiplier(comboCount: Int) -> Double {
        1 + bonusPerExtraCombo * Double(max(comboCount, 1) - 1)
    }

    /// 3 orbs = x1, each extra orb in the cluster adds `bonusPerExtraOrb`.
    public func orbMultiplier(orbCount: Int) -> Double {
        1 + bonusPerExtraOrb * Double(max(orbCount, 3) - 3)
    }
}

public struct PlayerAttack: Sendable {
    public let element: Element
    public let targetIndex: Int
    /// Raw damage before clamping to the enemy's remaining HP.
    public let damage: Int
    public let defeatedTarget: Bool
}

public struct EnemyAttack: Sendable {
    public let enemyIndex: Int
    /// HP actually removed from the player.
    public let damage: Int
}

public struct TurnReport: Sendable {
    public let turn: Int
    public let comboCount: Int
    public let playerAttacks: [PlayerAttack]
    public let healed: Int
    public let enemyAttacks: [EnemyAttack]
    public let outcome: BattleOutcome
}

/// Pure turn-based combat rules: player attack -> heal -> enemy countdown/attack.
public final class BattleEngine {
    public let mode: EncounterMode
    public let rules: CombatRules

    public private(set) var player: Player
    public private(set) var enemies: [Enemy]
    public private(set) var turn = 0
    private var preferredTarget: Int?

    private let initialPlayer: Player
    private let initialEnemies: [Enemy]

    public init(player: Player, enemies: [Enemy], mode: EncounterMode = .simultaneous, rules: CombatRules = CombatRules()) {
        precondition(!enemies.isEmpty, "A battle needs at least one enemy")
        self.player = player
        self.enemies = enemies
        self.mode = mode
        self.rules = rules
        self.initialPlayer = player
        self.initialEnemies = enemies
    }

    public var outcome: BattleOutcome {
        if player.isDefeated { return .defeat }
        if enemies.allSatisfy(\.isDefeated) { return .victory }
        return .ongoing
    }

    /// Enemies that can be targeted and whose countdown advances.
    public var activeEnemyIndices: [Int] {
        let alive = enemies.indices.filter { !enemies[$0].isDefeated }
        switch mode {
        case .simultaneous: return alive
        case .sequential: return Array(alive.prefix(1))
        }
    }

    /// The enemy that receives the next attack; falls back to the first active enemy.
    public var targetIndex: Int? {
        if let preferredTarget, activeEnemyIndices.contains(preferredTarget) { return preferredTarget }
        return activeEnemyIndices.first
    }

    @discardableResult
    public func selectTarget(_ index: Int) -> Bool {
        guard activeEnemyIndices.contains(index) else { return false }
        preferredTarget = index
        return true
    }

    /// Applies one player move. `clusters` are all combos of the move, cascades included.
    public func resolveTurn(clusters: [MatchCluster]) -> TurnReport {
        guard outcome == .ongoing else {
            return TurnReport(turn: turn, comboCount: 0, playerAttacks: [], healed: 0, enemyAttacks: [], outcome: outcome)
        }
        turn += 1
        let activeAtStart = Set(activeEnemyIndices)
        let comboMultiplier = rules.comboMultiplier(comboCount: clusters.count)

        var attacks: [PlayerAttack] = []
        var healed = 0

        for cluster in clusters {
            let base = rules.orbMultiplier(orbCount: cluster.count) * comboMultiplier
            if let element = cluster.type.element {
                guard let target = targetIndex else { continue }
                let raw = Double(player.attack[element] ?? 0) * base * element.multiplier(against: enemies[target].element)
                let damage = Int(raw.rounded())
                enemies[target].takeDamage(damage)
                attacks.append(PlayerAttack(element: element, targetIndex: target, damage: damage,
                                            defeatedTarget: enemies[target].isDefeated))
            } else {
                healed += player.heal(Int((Double(player.recovery) * base).rounded()))
            }
        }

        var enemyAttacks: [EnemyAttack] = []
        // Enemies that entered the field during this turn wait until the next one.
        for index in activeEnemyIndices where activeAtStart.contains(index) {
            guard outcome == .ongoing else { break }
            if enemies[index].advanceTurn() {
                enemyAttacks.append(EnemyAttack(enemyIndex: index, damage: player.takeDamage(enemies[index].attackPower)))
            }
        }

        return TurnReport(turn: turn, comboCount: clusters.count, playerAttacks: attacks, healed: healed,
                          enemyAttacks: enemyAttacks, outcome: outcome)
    }

    public func reset() {
        player = initialPlayer
        enemies = initialEnemies
        turn = 0
        preferredTarget = nil
    }
}
