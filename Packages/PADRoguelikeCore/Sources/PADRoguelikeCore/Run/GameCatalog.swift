import Foundation

/// Everything a run can draw from. Saves store only ids, resolved against this at load time.
public struct GameCatalog: Sendable {
    public var relics: [Relic]
    public var characters: [CharacterDefinition]
    public var enemies: [EnemyTemplate]
    public var events: [RunEvent]

    public init(relics: [Relic], characters: [CharacterDefinition], enemies: [EnemyTemplate], events: [RunEvent]) {
        self.relics = relics
        self.characters = characters
        self.enemies = enemies
        self.events = events
    }

    public func relic(id: String) -> Relic? { relics.first { $0.id == id } }
    public func character(id: String) -> CharacterDefinition? { characters.first { $0.id == id } }
    public func event(id: String) -> RunEvent? { events.first { $0.id == id } }

    public static let standard = GameCatalog(relics: Relic.standard,
                                             characters: CharacterDefinition.standard,
                                             enemies: EnemyTemplate.standard,
                                             events: RunEvent.standard)
}

public enum EnemyTier: String, Codable, Sendable {
    case minion, elite, boss
}

/// Unscaled enemy; `RunRules` turns it into an `Enemy` for a given row.
public struct EnemyTemplate: Hashable, Codable, Sendable {
    public let name: String
    public let element: Element
    public let tier: EnemyTier
    public let baseHP: Int
    public let baseAttack: Int
    public let turnInterval: Int
    public let traits: [EnemyTrait]
    /// First map row where it can appear.
    public let minRow: Int

    public init(name: String, element: Element, tier: EnemyTier, baseHP: Int, baseAttack: Int, turnInterval: Int,
                traits: [EnemyTrait] = [], minRow: Int = 0) {
        self.name = name
        self.element = element
        self.tier = tier
        self.baseHP = baseHP
        self.baseAttack = baseAttack
        self.turnInterval = turnInterval
        self.traits = traits
        self.minRow = minRow
    }

    public static let standard: [EnemyTemplate] = [
        // Minions
        EnemyTemplate(name: "Slime", element: .wood, tier: .minion, baseHP: 2_600, baseAttack: 400, turnInterval: 1),
        EnemyTemplate(name: "Fuoco Fatuo", element: .fire, tier: .minion, baseHP: 2_000, baseAttack: 700, turnInterval: 2),
        EnemyTemplate(name: "Granchio", element: .water, tier: .minion, baseHP: 3_400, baseAttack: 500, turnInterval: 2,
                      traits: [.armor(150)]),
        EnemyTemplate(name: "Pipistrello", element: .dark, tier: .minion, baseHP: 2_200, baseAttack: 450, turnInterval: 1),
        EnemyTemplate(name: "Fungo Velenoso", element: .wood, tier: .minion, baseHP: 3_000, baseAttack: 350, turnInterval: 1,
                      traits: [.regenerate(0.1)], minRow: 2),
        EnemyTemplate(name: "Spiritello", element: .light, tier: .minion, baseHP: 2_600, baseAttack: 800, turnInterval: 2,
                      traits: [.absorb(.dark)], minRow: 3),
        EnemyTemplate(name: "Scheletro", element: .dark, tier: .minion, baseHP: 3_800, baseAttack: 700, turnInterval: 2,
                      traits: [.enrage(0.3)], minRow: 3),
        EnemyTemplate(name: "Golem di Fango", element: .water, tier: .minion, baseHP: 5_500, baseAttack: 1_000, turnInterval: 3,
                      traits: [.armor(300)], minRow: 5),
        EnemyTemplate(name: "Mimic", element: .light, tier: .minion, baseHP: 4_200, baseAttack: 1_200, turnInterval: 3,
                      traits: [.comboShield(minCombos: 3)], minRow: 5),
        EnemyTemplate(name: "Salamandra", element: .fire, tier: .minion, baseHP: 3_600, baseAttack: 650, turnInterval: 1,
                      traits: [.enrage(0.15)], minRow: 7),

        // Elites
        EnemyTemplate(name: "Cavaliere Oscuro", element: .dark, tier: .elite, baseHP: 16_000, baseAttack: 1_600, turnInterval: 2,
                      traits: [.comboShield(minCombos: 4)]),
        EnemyTemplate(name: "Treant Antico", element: .wood, tier: .elite, baseHP: 20_000, baseAttack: 1_300, turnInterval: 3,
                      traits: [.regenerate(0.05), .armor(250)]),
        EnemyTemplate(name: "Drago Giovane", element: .fire, tier: .elite, baseHP: 15_000, baseAttack: 1_000, turnInterval: 1,
                      traits: [.enrage(0.2)]),
        EnemyTemplate(name: "Leviatano", element: .water, tier: .elite, baseHP: 18_000, baseAttack: 1_800, turnInterval: 2,
                      traits: [.absorb(.wood)]),

        // Bosses
        EnemyTemplate(name: "Drago Rosso", element: .fire, tier: .boss, baseHP: 48_000, baseAttack: 2_200, turnInterval: 2,
                      traits: [.enrage(0.15), .comboShield(minCombos: 4)]),
        EnemyTemplate(name: "Lich", element: .dark, tier: .boss, baseHP: 42_000, baseAttack: 1_900, turnInterval: 2,
                      traits: [.regenerate(0.03), .absorb(.light)]),
        EnemyTemplate(name: "Titano", element: .wood, tier: .boss, baseHP: 55_000, baseAttack: 2_800, turnInterval: 3,
                      traits: [.armor(400), .enrage(0.1)]),
    ]
}
