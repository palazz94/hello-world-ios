import Foundation

/// Condition on a single match.
public enum ClusterCondition: Hashable, Codable, Sendable {
    case orbsAtLeast(Int)
    case orbsAtMost(Int)
    case orbsExactly(Int)

    public func matches(_ cluster: MatchCluster) -> Bool {
        switch self {
        case let .orbsAtLeast(count): cluster.count >= count
        case let .orbsAtMost(count): cluster.count <= count
        case let .orbsExactly(count): cluster.count == count
        }
    }
}

/// Condition on a whole move (all combos, cascades included).
public enum TurnCondition: Hashable, Codable, Sendable {
    case combosAtLeast(Int)
    case combosAtMost(Int)
    /// Distinct orb types matched, hearts included.
    case colorsAtLeast(Int)
    /// Every listed type was matched at least once.
    case matched([OrbType])
    /// Total orbs cleared.
    case orbsAtLeast(Int)
    /// Player HP fraction at the start of the move.
    case hpBelow(Double)
    case hpAbove(Double)
}

/// A single typed effect. Relics, character talents and ability buffs are all lists of these.
public enum Modifier: Hashable, Codable, Sendable {
    // MARK: Damage
    /// Added to the base attack of `element` (nil = every element) before any multiplier.
    case flatDamage(element: Element?, amount: Int)
    /// Multiplies the final damage of `element` (nil = every element).
    case damageMultiplier(element: Element?, factor: Double)
    /// Multiplies the damage of each match meeting the condition.
    case clusterDamage(ClusterCondition, element: Element?, factor: Double)
    /// Multiplies all damage of a move meeting the condition.
    case turnDamage(TurnCondition, factor: Double)
    /// Added to `CombatRules.bonusPerExtraCombo` (can be negative).
    case comboBonus(Double)
    /// Added to `CombatRules.bonusPerExtraOrb` for `orb` (nil = every type).
    case orbBonus(orb: OrbType?, amount: Double)

    // MARK: Healing and HP
    case flatHeal(Int)
    case healMultiplier(Double)
    case maxHPMultiplier(Double)
    case healOnTurnStart(Int)
    /// Heals after a move meeting the condition.
    case turnHeal(TurnCondition, amount: Int)
    /// Lost at the start of every move; never below 1 HP.
    case hpLossOnTurnStart(Int)
    /// Lost after a move meeting the condition; never below 1 HP.
    case turnSelfDamage(TurnCondition, amount: Int)

    // MARK: Defense
    /// Fraction of incoming damage removed; the total is capped by `ModifierResolver.maxDamageReduction`.
    case damageReduction(Double)
    /// Multiplies incoming damage after reductions (above 1 is a drawback).
    case damageTakenMultiplier(Double)
    case shieldOnTurnStart(Int)
    /// Shield after a move meeting the condition.
    case turnShield(TurnCondition, amount: Int)

    // MARK: Board
    /// Seconds added to the move timer (negative = less time).
    case moveTime(Double)
}

/// A named group of modifiers, e.g. one relic or one talent. The name appears in resolver traces.
public struct ModifierSource: Hashable, Codable, Sendable {
    public let name: String
    public let modifiers: [Modifier]

    public init(name: String, modifiers: [Modifier]) {
        self.name = name
        self.modifiers = modifiers
    }
}

/// One entry of a resolver trace: which modifier changed a value and where it came from.
public struct AppliedModifier: Hashable, Sendable {
    public let source: String
    public let modifier: Modifier
}

/// A computed value plus the modifiers that contributed to it.
public struct Resolved<Value: Sendable>: Sendable {
    public let value: Value
    public let applied: [AppliedModifier]
}

/// What happened in one move, as seen by turn conditions.
public struct TurnContext: Sendable {
    public let clusters: [MatchCluster]
    public let hpFraction: Double

    public init(clusters: [MatchCluster], hpFraction: Double = 1) {
        self.clusters = clusters
        self.hpFraction = hpFraction
    }

    public var comboCount: Int { clusters.count }
    public var colors: Set<OrbType> { Set(clusters.map(\.type)) }
    public var orbCount: Int { clusters.reduce(0) { $0 + $1.count } }

    public func satisfies(_ condition: TurnCondition) -> Bool {
        switch condition {
        case let .combosAtLeast(count): comboCount >= count
        case let .combosAtMost(count): comboCount <= count
        case let .colorsAtLeast(count): colors.count >= count
        case let .matched(types): Set(types).isSubset(of: colors)
        case let .orbsAtLeast(count): orbCount >= count
        case let .hpBelow(fraction): hpFraction < fraction
        case let .hpAbove(fraction): hpFraction > fraction
        }
    }
}
