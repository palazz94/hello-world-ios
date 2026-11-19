import Foundation

/// Everything a run can draw from. Saves store only ids, resolved against this at load time.
public struct GameCatalog: Sendable {
    public var relics: [Relic]
    public var characters: [CharacterDefinition]
    public var enemies: [EnemyTemplate]

    public init(relics: [Relic], characters: [CharacterDefinition], enemies: [EnemyTemplate]) {
        self.relics = relics
        self.characters = characters
        self.enemies = enemies
    }

    public func relic(id: String) -> Relic? { relics.first { $0.id == id } }
    public func character(id: String) -> CharacterDefinition? { characters.first { $0.id == id } }

    public static let standard = GameCatalog(relics: Relic.standard,
                                             characters: CharacterDefinition.standard,
                                             enemies: EnemyTemplate.standard)
}

public enum EnemyTier: String, Codable, Sendable {
    case minion, elite, boss
}

/// Unscaled enemy; `RunRules` turns it into an `Enemy` for a given floor.
public struct EnemyTemplate: Hashable, Codable, Sendable {
    public let name: String
    public let element: Element
    public let tier: EnemyTier
    public let baseHP: Int
    public let baseAttack: Int
    public let turnInterval: Int

    public init(name: String, element: Element, tier: EnemyTier, baseHP: Int, baseAttack: Int, turnInterval: Int) {
        self.name = name
        self.element = element
        self.tier = tier
        self.baseHP = baseHP
        self.baseAttack = baseAttack
        self.turnInterval = turnInterval
    }

    public static let standard: [EnemyTemplate] = [
        EnemyTemplate(name: "Slime", element: .wood, tier: .minion, baseHP: 1_200, baseAttack: 250, turnInterval: 1),
        EnemyTemplate(name: "Fuoco Fatuo", element: .fire, tier: .minion, baseHP: 900, baseAttack: 400, turnInterval: 2),
        EnemyTemplate(name: "Granchio", element: .water, tier: .minion, baseHP: 1_600, baseAttack: 350, turnInterval: 2),
        EnemyTemplate(name: "Pipistrello", element: .dark, tier: .minion, baseHP: 1_000, baseAttack: 300, turnInterval: 1),
        EnemyTemplate(name: "Golem", element: .water, tier: .elite, baseHP: 6_000, baseAttack: 900, turnInterval: 2),
        EnemyTemplate(name: "Cavaliere Oscuro", element: .dark, tier: .elite, baseHP: 5_000, baseAttack: 1_100, turnInterval: 2),
        EnemyTemplate(name: "Treant", element: .wood, tier: .elite, baseHP: 7_000, baseAttack: 800, turnInterval: 3),
        EnemyTemplate(name: "Drago", element: .fire, tier: .boss, baseHP: 20_000, baseAttack: 2_200, turnInterval: 3),
        EnemyTemplate(name: "Lich", element: .dark, tier: .boss, baseHP: 18_000, baseAttack: 1_800, turnInterval: 2),
    ]
}
