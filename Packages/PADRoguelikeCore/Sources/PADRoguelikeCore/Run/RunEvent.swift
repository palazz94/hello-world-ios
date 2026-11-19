import Foundation

public enum EventEffect: Hashable, Codable, Sendable {
    /// Fraction of max HP; never lethal.
    case loseHP(Double)
    case heal(Double)
    case gainGold(Int)
    case loseGold(Int)
    /// A random unowned relic of at least this rarity.
    case gainRelic(Rarity)
    case levelUp
    /// Starts a fight (`.combat` or `.elite`); later effects of the option are ignored.
    case fight(NodeKind)
}

public struct EventOption: Hashable, Codable, Sendable {
    public let label: String
    public let effects: [EventEffect]

    public init(_ label: String, _ effects: [EventEffect] = []) {
        self.label = label
        self.effects = effects
    }

    public var goldCost: Int {
        effects.reduce(0) { total, effect in
            if case let .loseGold(amount) = effect { total + amount } else { total }
        }
    }
}

/// Text room with a choice, usually trading HP, gold or safety for power. Content lives in `Resources/events.json`.
public struct RunEvent: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let text: String
    public let options: [EventOption]

    public init(id: String, title: String, text: String, options: [EventOption]) {
        self.id = id
        self.title = title
        self.text = text
        self.options = options
    }
}
