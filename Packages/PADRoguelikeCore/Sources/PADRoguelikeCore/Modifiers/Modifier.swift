import Foundation

/// A single typed effect. Relics, character talents and ability buffs are all lists of these.
public enum Modifier: Hashable, Codable, Sendable {
    /// Added to the base attack of `element` (nil = every element) before any multiplier.
    case flatDamage(element: Element?, amount: Int)
    /// Multiplies the final damage of `element` (nil = every element).
    case damageMultiplier(element: Element?, factor: Double)
    /// Added to `CombatRules.bonusPerExtraCombo`.
    case comboBonus(Double)
    /// Added to `CombatRules.bonusPerExtraOrb` for clusters of `orb` (nil = every orb type).
    case orbBonus(orb: OrbType?, amount: Double)
    /// Added to the base recovery before multipliers.
    case flatHeal(Int)
    case healMultiplier(Double)
    case maxHPMultiplier(Double)
    /// Fraction of incoming enemy damage removed; the total is capped by `ModifierResolver.maxDamageReduction`.
    case damageReduction(Double)
    case shieldOnTurnStart(Int)
    case healOnTurnStart(Int)
    /// Grants shield once per move that reaches `minCombos`.
    case shieldOnCombo(minCombos: Int, amount: Int)
    /// Multiplies all damage of a move that reaches `minCombos`.
    case damageOnCombo(minCombos: Int, factor: Double)
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

extension Modifier: CustomStringConvertible {
    public var description: String {
        func scope(_ element: Element?) -> String { element?.rawValue ?? "all" }
        func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
        switch self {
        case let .flatDamage(element, amount): return "+\(amount) attack (\(scope(element)))"
        case let .damageMultiplier(element, factor): return "x\(factor) damage (\(scope(element)))"
        case let .comboBonus(amount): return "+\(percent(amount)) per extra combo"
        case let .orbBonus(orb, amount):
            return "+\(percent(amount)) per extra orb (\(orb.map { String(describing: $0) } ?? "all"))"
        case let .flatHeal(amount): return "+\(amount) recovery"
        case let .healMultiplier(factor): return "x\(factor) heal"
        case let .maxHPMultiplier(factor): return "x\(factor) max HP"
        case let .damageReduction(amount): return "-\(percent(amount)) damage taken"
        case let .shieldOnTurnStart(amount): return "+\(amount) shield each turn"
        case let .healOnTurnStart(amount): return "+\(amount) HP each turn"
        case let .shieldOnCombo(minCombos, amount): return "+\(amount) shield at \(minCombos)+ combos"
        case let .damageOnCombo(minCombos, factor): return "x\(factor) damage at \(minCombos)+ combos"
        }
    }
}
