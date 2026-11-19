import Foundation

public enum Rarity: Int, Codable, Comparable, Sendable {
    case common, rare, legendary

    public static func < (lhs: Rarity, rhs: Rarity) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct Relic: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let rarity: Rarity
    /// One-line flavour shown under the effects.
    public let flavor: String
    public let modifiers: [Modifier]

    public init(id: String, name: String, rarity: Rarity, flavor: String = "", modifiers: [Modifier]) {
        self.id = id
        self.name = name
        self.rarity = rarity
        self.flavor = flavor
        self.modifiers = modifiers
    }

    public var source: ModifierSource { ModifierSource(name: name, modifiers: modifiers) }
}

public extension Relic {
    static let standard: [Relic] = [
        // MARK: Common
        Relic(id: "four-leaf-lens", name: "Lente Quadrifoglio", rarity: .common,
              flavor: "Quattro è il numero perfetto.",
              modifiers: [.clusterDamage(.orbsExactly(4), element: nil, factor: 1.5)]),
        Relic(id: "giant-hammer", name: "Martello del Gigante", rarity: .common,
              flavor: "Colpi enormi, ma i piccoli non contano.",
              modifiers: [.clusterDamage(.orbsAtLeast(5), element: nil, factor: 1.7),
                          .clusterDamage(.orbsExactly(3), element: nil, factor: 0.8)]),
        Relic(id: "metronome", name: "Metronomo", rarity: .common,
              flavor: "Tieni il ritmo.",
              modifiers: [.turnDamage(.combosAtLeast(5), factor: 1.4)]),
        Relic(id: "cracked-prism", name: "Prisma Incrinato", rarity: .common,
              flavor: "Ogni colore lo fa brillare un po' di più.",
              modifiers: [.turnDamage(.colorsAtLeast(3), factor: 1.3)]),
        Relic(id: "red-vial", name: "Ampolla Rossa", rarity: .common,
              modifiers: [.turnHeal(.combosAtLeast(4), amount: 300)]),
        Relic(id: "turtle-scale", name: "Scaglia di Tartaruga", rarity: .common,
              flavor: "Lenta ma sicura.",
              modifiers: [.shieldOnTurnStart(250), .moveTime(-0.5)]),
        Relic(id: "hourglass", name: "Clessidra", rarity: .common,
              flavor: "Più tempo, meno forza.",
              modifiers: [.moveTime(1.5), .damageMultiplier(element: nil, factor: 0.9)]),
        Relic(id: "twin-pearls", name: "Perle Gemelle", rarity: .common,
              modifiers: [.turnDamage(.matched([.fire, .water]), factor: 1.6)]),
        Relic(id: "deep-root", name: "Radice Profonda", rarity: .common,
              modifiers: [.turnDamage(.matched([.wood, .heal]), factor: 1.5)]),
        Relic(id: "loaded-coin", name: "Moneta Truccata", rarity: .common,
              flavor: "Vinci di più, ma qualcuno se ne accorge.",
              modifiers: [.flatDamage(element: nil, amount: 200), .damageTakenMultiplier(1.15)]),

        // MARK: Rare
        Relic(id: "bloody-blade", name: "Lama Insanguinata", rarity: .rare,
              flavor: "Chiede un tributo a ogni colpo.",
              modifiers: [.damageMultiplier(element: nil, factor: 1.5), .hpLossOnTurnStart(120)]),
        Relic(id: "berserker-mask", name: "Maschera del Berserker", rarity: .rare,
              flavor: "Più sanguini, più colpisci.",
              modifiers: [.turnDamage(.hpBelow(0.4), factor: 2.0)]),
        Relic(id: "balance-crown", name: "Corona dell'Equilibrio", rarity: .rare,
              flavor: "Premia chi non si fa colpire.",
              modifiers: [.turnDamage(.hpAbove(0.8), factor: 1.45)]),
        Relic(id: "blood-contract", name: "Contratto di Sangue", rarity: .rare,
              modifiers: [.damageMultiplier(element: nil, factor: 1.4), .healMultiplier(0.5)]),
        Relic(id: "glass-heart", name: "Cuore di Vetro", rarity: .rare,
              flavor: "Fortissimo. Fragilissimo.",
              modifiers: [.maxHPMultiplier(0.7), .damageMultiplier(element: nil, factor: 1.5)]),
        Relic(id: "chain", name: "Catena", rarity: .rare,
              flavor: "Ogni anello conta. Se ne manca uno, fa male.",
              modifiers: [.comboBonus(0.15), .turnSelfDamage(.combosAtMost(2), amount: 400)]),
        Relic(id: "rainbow-eye", name: "Occhio dell'Arcobaleno", rarity: .rare,
              modifiers: [.turnDamage(.colorsAtLeast(5), factor: 2.2)]),
        Relic(id: "broken-hourglass", name: "Clessidra Spezzata", rarity: .rare,
              flavor: "Il tempo scorre più in fretta.",
              modifiers: [.moveTime(-1.5), .damageMultiplier(element: nil, factor: 1.6)]),
        Relic(id: "thorn-armor", name: "Armatura di Spine", rarity: .rare,
              modifiers: [.damageReduction(0.25), .moveTime(-1)]),
        Relic(id: "seal-of-four", name: "Sigillo del Quattro", rarity: .rare,
              modifiers: [.clusterDamage(.orbsExactly(4), element: nil, factor: 1.9),
                          .clusterDamage(.orbsAtLeast(5), element: nil, factor: 0.7)]),

        // MARK: Legendary
        Relic(id: "chaos-crown", name: "Corona del Caos", rarity: .legendary,
              modifiers: [.turnDamage(.combosAtLeast(7), factor: 2.5), .turnShield(.combosAtLeast(5), amount: 600)]),
        Relic(id: "dark-pact", name: "Patto Oscuro", rarity: .legendary,
              flavor: "Il doppio della forza. Il doppio del dolore.",
              modifiers: [.damageMultiplier(element: nil, factor: 2.0), .damageTakenMultiplier(1.5),
                          .healMultiplier(0.5)]),
        Relic(id: "phoenix-heart", name: "Cuore di Fenice", rarity: .legendary,
              flavor: "Rinasce quando sta per spegnersi.",
              modifiers: [.turnHeal(.hpBelow(0.35), amount: 1_000), .turnDamage(.hpBelow(0.35), factor: 1.5)]),
        Relic(id: "singularity", name: "Singolarità", rarity: .legendary,
              modifiers: [.clusterDamage(.orbsAtLeast(6), element: nil, factor: 3.0), .comboBonus(-0.1)]),
    ]
}
