import Foundation

/// Special rules that make an enemy play differently.
public enum EnemyTrait: Hashable, Codable, Sendable {
    /// Immune to moves with fewer combos (abilities ignore it).
    case comboShield(minCombos: Int)
    /// Attack grows by this fraction after every attack.
    case enrage(Double)
    /// Heals this fraction of max HP after every player move.
    case regenerate(Double)
    /// Damage of this element heals it instead.
    case absorb(Element)
    /// Removed from every hit.
    case armor(Int)
}

public enum HitBlock: Hashable, Sendable {
    case comboShield, absorbed
}

public struct Enemy: Identifiable, Equatable, Codable, Sendable {
    public let id: Int
    public let name: String
    public let element: Element
    public let maxHP: Int
    public private(set) var currentHP: Int
    public let attackPower: Int
    /// Player moves between two attacks.
    public let turnInterval: Int
    /// Player moves left before the next attack.
    public private(set) var turnCountdown: Int
    public let traits: [EnemyTrait]
    public private(set) var rage = 1.0

    public var isDefeated: Bool { currentHP <= 0 }
    /// Damage of the next attack, enrage included.
    public var currentAttack: Int { Int((Double(attackPower) * rage).rounded()) }

    public init(id: Int, name: String, element: Element, maxHP: Int, attackPower: Int, turnInterval: Int,
                traits: [EnemyTrait] = []) {
        precondition(maxHP > 0 && turnInterval > 0, "maxHP and turnInterval must be positive")
        self.id = id
        self.name = name
        self.element = element
        self.maxHP = maxHP
        self.currentHP = maxHP
        self.attackPower = attackPower
        self.turnInterval = turnInterval
        self.turnCountdown = turnInterval
        self.traits = traits
    }

    mutating func takeDamage(_ amount: Int) {
        currentHP = max(0, currentHP - max(0, amount))
    }

    /// Applies traits to an incoming hit. `comboCount` is nil for abilities.
    /// Returns the damage after armor (not clamped to remaining HP), or the HP healed when absorbed.
    mutating func receiveHit(_ amount: Int, element: Element, comboCount: Int?) -> (amount: Int, block: HitBlock?) {
        var amount = max(0, amount)
        for trait in traits {
            switch trait {
            case let .absorb(absorbed) where absorbed == element:
                let healed = min(amount, maxHP - currentHP)
                currentHP += healed
                return (healed, .absorbed)
            case let .comboShield(minCombos):
                if let comboCount, comboCount < minCombos { return (0, .comboShield) }
            case let .armor(value):
                amount = max(0, amount - value)
            default:
                continue
            }
        }
        takeDamage(amount)
        return (amount, nil)
    }

    /// Returns HP regenerated.
    mutating func regenerate() -> Int {
        guard !isDefeated else { return 0 }
        let fraction = traits.reduce(0.0) { total, trait in
            if case let .regenerate(value) = trait { total + value } else { total }
        }
        let healed = min(maxHP - currentHP, Int((Double(maxHP) * fraction).rounded()))
        currentHP += healed
        return healed
    }

    /// Decrements the countdown; returns `true` when the enemy attacks this turn.
    mutating func advanceTurn() -> Bool {
        guard !isDefeated else { return false }
        turnCountdown -= 1
        guard turnCountdown <= 0 else { return false }
        turnCountdown = turnInterval
        return true
    }

    mutating func didAttack() {
        for case let .enrage(value) in traits { rage += value }
    }

    mutating func delay(by turns: Int) {
        guard !isDefeated else { return }
        turnCountdown += max(0, turns)
    }
}

public extension Enemy {
    /// Weak minion, mid tank, test boss.
    static let testRoster: [Enemy] = [
        Enemy(id: 0, name: "Slime", element: .wood, maxHP: 1_500, attackPower: 300, turnInterval: 1),
        Enemy(id: 1, name: "Golem", element: .water, maxHP: 6_000, attackPower: 900, turnInterval: 2),
        Enemy(id: 2, name: "Drago", element: .fire, maxHP: 15_000, attackPower: 2_500, turnInterval: 3),
    ]
}
