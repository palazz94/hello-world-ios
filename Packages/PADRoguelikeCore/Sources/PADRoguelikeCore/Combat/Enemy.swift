import Foundation

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

    public var isDefeated: Bool { currentHP <= 0 }

    public init(id: Int, name: String, element: Element, maxHP: Int, attackPower: Int, turnInterval: Int) {
        precondition(maxHP > 0 && turnInterval > 0, "maxHP and turnInterval must be positive")
        self.id = id
        self.name = name
        self.element = element
        self.maxHP = maxHP
        self.currentHP = maxHP
        self.attackPower = attackPower
        self.turnInterval = turnInterval
        self.turnCountdown = turnInterval
    }

    mutating func takeDamage(_ amount: Int) {
        currentHP = max(0, currentHP - max(0, amount))
    }

    /// Decrements the countdown; returns `true` when the enemy attacks this turn.
    mutating func advanceTurn() -> Bool {
        guard !isDefeated else { return false }
        turnCountdown -= 1
        guard turnCountdown <= 0 else { return false }
        turnCountdown = turnInterval
        return true
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
