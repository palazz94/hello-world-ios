import Foundation

/// Applies modifiers to combat values in a fixed order, so results never depend on how sources are listed:
/// additive terms are summed first, then multipliers are multiplied together.
///
/// Damage per match: `(attack + flat) x orbMultiplier x comboMultiplier x elementAdvantage x product(factors)`.
public struct ModifierResolver: Sendable {
    public static let maxDamageReduction = 0.75

    public var rules: CombatRules
    public var sources: [ModifierSource]

    public init(rules: CombatRules = CombatRules(), sources: [ModifierSource] = []) {
        self.rules = rules
        self.sources = sources
    }

    /// Every modifier with its source, in source order.
    public var entries: [AppliedModifier] {
        sources.flatMap { source in source.modifiers.map { AppliedModifier(source: source.name, modifier: $0) } }
    }

    public func damage(attack: Int, element: Element, cluster: MatchCluster, turn: TurnContext,
                       defender: Element) -> Resolved<Int> {
        var base = Double(attack)
        var orbBonus = rules.bonusPerExtraOrb
        var comboBonus = rules.bonusPerExtraCombo
        var factor = 1.0
        var applied: [AppliedModifier] = []

        for entry in entries {
            switch entry.modifier {
            case let .flatDamage(scope, amount) where matches(scope, element):
                base += Double(amount)
            case let .orbBonus(scope, amount) where matches(scope, cluster.type) && cluster.count > 3:
                orbBonus += amount
            case let .comboBonus(amount) where turn.comboCount > 1:
                comboBonus += amount
            case let .damageMultiplier(scope, value) where matches(scope, element):
                factor *= value
            case let .clusterDamage(condition, scope, value) where matches(scope, element) && condition.matches(cluster):
                factor *= value
            case let .turnDamage(condition, value) where turn.satisfies(condition):
                factor *= value
            default:
                continue
            }
            applied.append(entry)
        }

        let scaled = CombatRules(bonusPerExtraCombo: comboBonus, bonusPerExtraOrb: orbBonus)
        let value = base * scaled.orbMultiplier(orbCount: cluster.count) * scaled.comboMultiplier(comboCount: turn.comboCount)
            * element.multiplier(against: defender) * factor
        return Resolved(value: max(0, Int(value.rounded())), applied: applied)
    }

    public func heal(recovery: Int, cluster: MatchCluster, turn: TurnContext) -> Resolved<Int> {
        var base = Double(recovery)
        var orbBonus = rules.bonusPerExtraOrb
        var comboBonus = rules.bonusPerExtraCombo
        var factor = 1.0
        var applied: [AppliedModifier] = []

        for entry in entries {
            switch entry.modifier {
            case let .flatHeal(amount):
                base += Double(amount)
            case let .orbBonus(scope, amount) where matches(scope, cluster.type) && cluster.count > 3:
                orbBonus += amount
            case let .comboBonus(amount) where turn.comboCount > 1:
                comboBonus += amount
            case let .healMultiplier(value):
                factor *= value
            default:
                continue
            }
            applied.append(entry)
        }

        let scaled = CombatRules(bonusPerExtraCombo: comboBonus, bonusPerExtraOrb: orbBonus)
        let value = base * scaled.orbMultiplier(orbCount: cluster.count) * scaled.comboMultiplier(comboCount: turn.comboCount) * factor
        return Resolved(value: max(0, Int(value.rounded())), applied: applied)
    }

    /// Enemy damage after reductions and drawbacks, before the shield.
    public func incomingDamage(_ raw: Int) -> Resolved<Int> {
        var reduction = 0.0
        var factor = 1.0
        var applied: [AppliedModifier] = []
        for entry in entries {
            switch entry.modifier {
            case let .damageReduction(amount): reduction += amount
            case let .damageTakenMultiplier(value): factor *= value
            default: continue
            }
            applied.append(entry)
        }
        let kept = (1 - min(max(reduction, 0), Self.maxDamageReduction)) * factor
        return Resolved(value: max(0, Int((Double(raw) * kept).rounded())), applied: applied)
    }

    public func turnStartShield() -> Resolved<Int> {
        sum { if case let .shieldOnTurnStart(amount) = $0 { amount } else { nil } }
    }

    public func turnStartHeal() -> Resolved<Int> {
        sum { if case let .healOnTurnStart(amount) = $0 { amount } else { nil } }
    }

    public func turnStartHPLoss() -> Resolved<Int> {
        sum { if case let .hpLossOnTurnStart(amount) = $0 { amount } else { nil } }
    }

    public func moveShield(_ turn: TurnContext) -> Resolved<Int> {
        sum { if case let .turnShield(condition, amount) = $0, turn.satisfies(condition) { amount } else { nil } }
    }

    public func moveHeal(_ turn: TurnContext) -> Resolved<Int> {
        sum { if case let .turnHeal(condition, amount) = $0, turn.satisfies(condition) { amount } else { nil } }
    }

    public func moveSelfDamage(_ turn: TurnContext) -> Resolved<Int> {
        sum { if case let .turnSelfDamage(condition, amount) = $0, turn.satisfies(condition) { amount } else { nil } }
    }

    /// Seconds to add to the base move time.
    public func moveTimeBonus() -> Double {
        entries.reduce(0) { total, entry in
            if case let .moveTime(seconds) = entry.modifier { total + seconds } else { total }
        }
    }

    public func maxHP(_ base: Int) -> Resolved<Int> {
        var factor = 1.0
        var applied: [AppliedModifier] = []
        for entry in entries {
            guard case let .maxHPMultiplier(value) = entry.modifier else { continue }
            factor *= value
            applied.append(entry)
        }
        return Resolved(value: max(1, Int((Double(base) * factor).rounded())), applied: applied)
    }

    private func sum(_ amount: (Modifier) -> Int?) -> Resolved<Int> {
        var total = 0
        var applied: [AppliedModifier] = []
        for entry in entries {
            guard let value = amount(entry.modifier) else { continue }
            total += value
            applied.append(entry)
        }
        return Resolved(value: total, applied: applied)
    }

    private func matches<T: Equatable>(_ scope: T?, _ value: T) -> Bool {
        scope == nil || scope == value
    }
}
