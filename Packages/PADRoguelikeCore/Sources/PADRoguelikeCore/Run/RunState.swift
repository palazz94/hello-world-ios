import Foundation

public enum NodeKind: String, Codable, Sendable {
    case combat, elite, rest, treasure, boss

    public var isCombat: Bool { self == .combat || self == .elite || self == .boss }
}

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
}

/// Complete, serializable state of a run. Encode it with `JSONEncoder` to save, decode and pass to
/// `RunEngine(restoring:)` to resume exactly where it stopped, random draws included.
public struct RunState: Equatable, Codable, Sendable {
    public enum Phase: Equatable, Codable, Sendable {
        case choosingNode([NodeKind])
        case inCombat(Encounter)
        case choosingReward([Reward])
        case won
        case lost
    }

    public let seed: UInt64
    public internal(set) var rng: SeededRandom
    /// 0-based; the run is won after clearing the last floor.
    public internal(set) var floor = 0
    public internal(set) var phase: Phase
    public let characterID: String
    public internal(set) var characterLevel = 1
    public internal(set) var relicIDs: [String] = []
    /// Stored as damage taken so max-HP changes (level-ups, relics) keep current HP consistent.
    public internal(set) var missingHP = 0
    public internal(set) var visited: [NodeKind] = []

    init(seed: UInt64, rng: SeededRandom, phase: Phase, characterID: String) {
        self.seed = seed
        self.rng = rng
        self.phase = phase
        self.characterID = characterID
    }
}
