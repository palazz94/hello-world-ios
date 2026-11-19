import Foundation

public struct Encounter: Equatable, Codable, Sendable {
    public let kind: NodeKind
    public let mode: EncounterMode
    public let enemies: [Enemy]

    public init(kind: NodeKind, mode: EncounterMode, enemies: [Enemy]) {
        precondition(!enemies.isEmpty, "An encounter needs at least one enemy")
        self.kind = kind
        self.mode = mode
        self.enemies = enemies
    }
}

public enum Reward: Hashable, Codable, Sendable {
    case relic(id: String)
    case levelUp
    /// Heals a fraction of max HP.
    case heal(Double)
    case gold(Int)
}

public struct ShopItem: Hashable, Codable, Sendable {
    public let reward: Reward
    public let price: Int
    public internal(set) var sold = false

    public init(reward: Reward, price: Int) {
        self.reward = reward
        self.price = price
    }
}

public enum RestOption: Hashable, Codable, Sendable {
    case heal, train
}

/// Complete, serializable state of a run. Encode it with `JSONEncoder` to save, decode and pass to
/// `RunEngine(restoring:)` to resume exactly where it stopped, random draws included.
public struct RunState: Equatable, Codable, Sendable {
    public enum Phase: Equatable, Codable, Sendable {
        /// Pick the next node among `RunEngine.reachableNodes`.
        case map
        case inCombat(Encounter)
        case choosingReward([Reward])
        case event(id: String)
        case shop([ShopItem])
        case resting
        case won
        case lost
    }

    public let seed: UInt64
    public internal(set) var rng: SeededRandom
    public let map: RunMap
    public internal(set) var currentNodeID: Int?
    /// Visited node ids, in order.
    public internal(set) var path: [Int] = []
    public internal(set) var phase: Phase = .map
    public let characterID: String
    public internal(set) var characterLevel = 1
    public internal(set) var relicIDs: [String] = []
    /// Stored as damage taken so max-HP changes (level-ups, relics) keep current HP consistent.
    public internal(set) var missingHP = 0
    public internal(set) var gold = 0
    public internal(set) var seenEventIDs: [String] = []

    init(seed: UInt64, rng: SeededRandom, map: RunMap, characterID: String) {
        self.seed = seed
        self.rng = rng
        self.map = map
        self.characterID = characterID
    }

    /// Row of the current node, -1 before the first step.
    public var row: Int { currentNodeID.flatMap(map.node)?.row ?? -1 }
}
