import Foundation

public enum Rarity: Int, Codable, Comparable, Sendable {
    case common, rare, legendary

    public static func < (lhs: Rarity, rhs: Rarity) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Content lives in `Resources/relics.json`.
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
