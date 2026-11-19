import Foundation

public enum Rarity: Int, Codable, Comparable, Sendable {
    case common, rare, legendary

    public static func < (lhs: Rarity, rhs: Rarity) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct Relic: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let rarity: Rarity
    public let modifiers: [Modifier]

    public init(id: String, name: String, rarity: Rarity, modifiers: [Modifier]) {
        self.id = id
        self.name = name
        self.rarity = rarity
        self.modifiers = modifiers
    }

    public var source: ModifierSource { ModifierSource(name: name, modifiers: modifiers) }
}

public extension Relic {
    static let standard: [Relic] = [
        Relic(id: "eternal-ember", name: "Brace Eterna", rarity: .common,
              modifiers: [.damageMultiplier(element: .fire, factor: 1.5)]),
        Relic(id: "tide-pearl", name: "Perla di Marea", rarity: .common,
              modifiers: [.damageMultiplier(element: .water, factor: 1.5)]),
        Relic(id: "ancient-seed", name: "Seme Antico", rarity: .common,
              modifiers: [.damageMultiplier(element: .wood, factor: 1.5)]),
        Relic(id: "oak-shield", name: "Scudo di Quercia", rarity: .common,
              modifiers: [.shieldOnTurnStart(150)]),
        Relic(id: "chalice", name: "Calice", rarity: .common,
              modifiers: [.flatHeal(50), .healMultiplier(1.5)]),
        Relic(id: "prism", name: "Prisma", rarity: .rare,
              modifiers: [.comboBonus(0.1)]),
        Relic(id: "crystal-lens", name: "Lente di Cristallo", rarity: .rare,
              modifiers: [.orbBonus(orb: nil, amount: 0.15)]),
        Relic(id: "scale-armor", name: "Armatura di Scaglie", rarity: .rare,
              modifiers: [.damageReduction(0.2)]),
        Relic(id: "giant-heart", name: "Cuore di Gigante", rarity: .rare,
              modifiers: [.maxHPMultiplier(1.25)]),
        Relic(id: "chaos-crown", name: "Corona del Caos", rarity: .legendary,
              modifiers: [.damageOnCombo(minCombos: 5, factor: 1.5), .shieldOnCombo(minCombos: 4, amount: 400)]),
    ]
}
