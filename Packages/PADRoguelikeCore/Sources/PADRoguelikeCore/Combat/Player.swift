import Foundation

public struct Player: Equatable, Sendable {
    public let maxHP: Int
    public private(set) var currentHP: Int
    /// Base damage of a 3-orb, 1-combo match per element.
    public let attack: [Element: Int]
    /// Base HP recovered by a 3-orb, 1-combo heal match.
    public let recovery: Int

    public var isDefeated: Bool { currentHP <= 0 }

    /// `currentHP` defaults to full and is clamped to `0...maxHP`.
    public init(maxHP: Int, attack: [Element: Int], recovery: Int, currentHP: Int? = nil) {
        precondition(maxHP > 0, "maxHP must be positive")
        self.maxHP = maxHP
        self.currentHP = min(max(currentHP ?? maxHP, 0), maxHP)
        self.attack = attack
        self.recovery = recovery
    }

    /// Returns the HP actually lost.
    mutating func takeDamage(_ amount: Int) -> Int {
        let lost = min(currentHP, max(0, amount))
        currentHP -= lost
        return lost
    }

    /// Returns the HP actually recovered.
    mutating func heal(_ amount: Int) -> Int {
        let gained = min(maxHP - currentHP, max(0, amount))
        currentHP += gained
        return gained
    }
}

public extension Player {
    static let test = Player(
        maxHP: 5_000,
        attack: [.fire: 1_000, .water: 1_000, .wood: 1_000, .light: 800, .dark: 800],
        recovery: 300
    )
}
