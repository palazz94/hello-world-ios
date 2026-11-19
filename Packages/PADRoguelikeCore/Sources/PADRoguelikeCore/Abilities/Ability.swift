import Foundation

public enum AbilityTarget: String, Hashable, Codable, Sendable {
    case selectedEnemy, allEnemies
}

public enum AbilityEffect: Hashable, Codable, Sendable {
    /// Damage = character attack x `multiplier` x element advantage. Not affected by relics.
    case damage(target: AbilityTarget, element: Element, multiplier: Double)
    /// Heals a fraction of max HP.
    case healPercent(Double)
    case shield(Int)
    /// Pushes back the attack countdown of every active enemy.
    case delayEnemies(turns: Int)
    /// Adds a temporary modifier source for `turns` player moves, the current one included.
    case buff(ModifierSource, turns: Int)
    case convertOrbs(from: OrbType, to: OrbType)
    case refreshBoard

    var needsBoard: Bool {
        switch self {
        case .convertOrbs, .refreshBoard: true
        default: false
        }
    }
}

/// Active skill, used before a move. Ready again `cooldown` moves after use.
public struct Ability: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let cooldown: Int
    /// Uses per battle; nil means unlimited.
    public let charges: Int?
    /// HP paid on use; the ability cannot be used if it would defeat the player.
    public let hpCost: Int
    public let effects: [AbilityEffect]

    public init(id: String, name: String, cooldown: Int, charges: Int? = nil, hpCost: Int = 0, effects: [AbilityEffect]) {
        self.id = id
        self.name = name
        self.cooldown = max(0, cooldown)
        self.charges = charges
        self.hpCost = max(0, hpCost)
        self.effects = effects
    }

    public var needsBoard: Bool { effects.contains(where: \.needsBoard) }
}

/// An ability inside a battle, with its owner and remaining cooldown/charges.
public struct AbilityState: Hashable, Codable, Sendable {
    public let ability: Ability
    public let owner: String
    public private(set) var cooldownRemaining = 0
    public private(set) var chargesLeft: Int?

    public init(ability: Ability, owner: String) {
        self.ability = ability
        self.owner = owner
        self.chargesLeft = ability.charges
    }

    public var isReady: Bool { cooldownRemaining == 0 && chargesLeft != 0 }

    mutating func consume() {
        cooldownRemaining = ability.cooldown
        if let chargesLeft { self.chargesLeft = chargesLeft - 1 }
    }

    mutating func tick() {
        cooldownRemaining = max(0, cooldownRemaining - 1)
    }
}

public struct TimedBuff: Hashable, Codable, Sendable {
    public let source: ModifierSource
    public let remainingTurns: Int

    func ticked() -> TimedBuff? {
        remainingTurns > 1 ? TimedBuff(source: source, remainingTurns: remainingTurns - 1) : nil
    }
}

public enum AbilityError: Error, Equatable, Sendable {
    case invalidIndex, battleOver, onCooldown, noCharges, notEnoughHP, needsBoard
}

public struct AbilityReport: Sendable {
    public let abilityIndex: Int
    public internal(set) var attacks: [PlayerAttack] = []
    public internal(set) var healed = 0
    public internal(set) var shieldGained = 0
    public internal(set) var delayedEnemies: [Int] = []
    public internal(set) var conversions: [OrbConversion] = []
    public internal(set) var boardRefreshed = false
    public internal(set) var outcome: BattleOutcome = .ongoing
}
