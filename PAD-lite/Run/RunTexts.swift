import PADRoguelikeCore
import SwiftUI

// Italian UI texts for core types.

private func percent(_ value: Double) -> String { "\(Int((abs(value) * 100).rounded()))%" }
private func times(_ value: Double) -> String { "×" + value.formatted(.number.precision(.fractionLength(0...2))) }
private func turns(_ count: Int) -> String { count == 1 ? "1 turno" : "\(count) turni" }
private func scope(_ element: Element?) -> String { element.map { " \($0.displayName)" } ?? "" }

extension OrbType {
    var displayName: String { element?.displayName ?? "Cuore" }
}

extension ClusterCondition {
    var displayText: String {
        switch self {
        case let .orbsAtLeast(count): "match da \(count)+ sfere"
        case let .orbsAtMost(count): "match da \(count) sfere o meno"
        case let .orbsExactly(count): "match da esattamente \(count) sfere"
        }
    }
}

extension TurnCondition {
    var displayText: String {
        switch self {
        case let .combosAtLeast(count): "con \(count)+ combo"
        case let .combosAtMost(count): "con \(count) combo o meno"
        case let .colorsAtLeast(count): "con \(count)+ colori diversi"
        case let .matched(types): "abbinando " + types.map(\.displayName).joined(separator: " + ")
        case let .orbsAtLeast(count): "eliminando \(count)+ sfere"
        case let .hpBelow(fraction): "sotto il \(percent(fraction)) degli HP"
        case let .hpAbove(fraction): "sopra il \(percent(fraction)) degli HP"
        }
    }
}

extension Modifier {
    var displayText: String {
        switch self {
        case let .flatDamage(element, amount): "\(amount >= 0 ? "+" : "−")\(abs(amount)) attacco\(scope(element))"
        case let .damageMultiplier(element, factor): "Danno\(scope(element)) \(times(factor))"
        case let .clusterDamage(condition, element, factor): "Danno\(scope(element)) \(times(factor)) nei \(condition.displayText)"
        case let .turnDamage(condition, factor): "Danno \(times(factor)) \(condition.displayText)"
        case let .comboBonus(amount): "\(amount >= 0 ? "+" : "−")\(percent(amount)) per ogni combo extra"
        case let .orbBonus(orb, amount):
            "\(amount >= 0 ? "+" : "−")\(percent(amount)) per sfera extra" + (orb.map { " (\($0.displayName))" } ?? "")
        case let .flatHeal(amount): "+\(amount) cura"
        case let .healMultiplier(factor): "Cura \(times(factor))"
        case let .maxHPMultiplier(factor): "HP massimi \(times(factor))"
        case let .healOnTurnStart(amount): "+\(amount) HP a ogni turno"
        case let .turnHeal(condition, amount): "+\(amount) HP \(condition.displayText)"
        case let .hpLossOnTurnStart(amount): "−\(amount) HP a ogni turno"
        case let .turnSelfDamage(condition, amount): "−\(amount) HP \(condition.displayText)"
        case let .damageReduction(amount): "−\(percent(amount)) danni subiti"
        case let .damageTakenMultiplier(factor): "Danni subiti \(times(factor))"
        case let .shieldOnTurnStart(amount): "+\(amount) scudo a ogni turno"
        case let .turnShield(condition, amount): "+\(amount) scudo \(condition.displayText)"
        case let .moveTime(seconds):
            "\(seconds >= 0 ? "+" : "−")\(abs(seconds).formatted(.number.precision(.fractionLength(0...1)))) s per muovere"
        }
    }

    /// The "risk" half of a risk/reward effect; shown in red.
    var isDrawback: Bool {
        switch self {
        case let .flatDamage(_, amount): amount < 0
        case let .damageMultiplier(_, factor), let .clusterDamage(_, _, factor), let .turnDamage(_, factor): factor < 1
        case let .comboBonus(amount), let .orbBonus(_, amount): amount < 0
        case let .healMultiplier(factor), let .maxHPMultiplier(factor): factor < 1
        case .hpLossOnTurnStart, .turnSelfDamage: true
        case let .damageTakenMultiplier(factor): factor > 1
        case let .moveTime(seconds): seconds < 0
        default: false
        }
    }
}

extension EnemyTrait {
    var title: String {
        switch self {
        case .comboShield: "Scudo combo"
        case .enrage: "Rabbia"
        case .regenerate: "Rigenera"
        case let .absorb(element): "Assorbe \(element.displayName)"
        case .armor: "Armatura"
        }
    }

    var detail: String {
        switch self {
        case let .comboShield(minCombos): "Immune alle mosse con meno di \(minCombos) combo"
        case let .enrage(fraction): "+\(percent(fraction)) attacco dopo ogni attacco"
        case let .regenerate(fraction): "Recupera il \(percent(fraction)) degli HP a ogni turno"
        case let .absorb(element): "I danni \(element.displayName) lo curano"
        case let .armor(amount): "−\(amount) danni da ogni colpo"
        }
    }
}

extension AbilityEffect {
    var displayText: String {
        switch self {
        case let .damage(target, element, multiplier):
            "Danno \(element.displayName) \(times(multiplier)) a " + (target == .allEnemies ? "tutti i nemici" : "un nemico")
        case let .healPercent(fraction): "Cura il \(percent(fraction)) degli HP"
        case let .shield(amount): "+\(amount) scudo"
        case let .delayEnemies(count): "Ritarda i nemici di \(turns(count))"
        case let .buff(source, count): source.modifiers.map(\.displayText).joined(separator: ", ") + " per \(turns(count))"
        case let .convertOrbs(from, to): "Sfere \(from.displayName) → \(to.displayName)"
        case .refreshBoard: "Rigenera la griglia"
        }
    }
}

extension Ability {
    var summary: String {
        var parts = [effects.map(\.displayText).joined(separator: ", "), "ricarica \(turns(cooldown))"]
        if let charges { parts.append("\(charges) usi") }
        if hpCost > 0 { parts.append("costa \(hpCost) HP") }
        return parts.joined(separator: " · ")
    }
}

extension NodeKind {
    var title: String {
        switch self {
        case .combat: "Combattimento"
        case .elite: "Elite"
        case .event: "Evento"
        case .shop: "Mercante"
        case .rest: "Accampamento"
        case .treasure: "Tesoro"
        case .boss: "Boss"
        }
    }

    var symbol: String {
        switch self {
        case .combat: "figure.fencing"
        case .elite: "flame.fill"
        case .event: "questionmark"
        case .shop: "cart.fill"
        case .rest: "tent.fill"
        case .treasure: "shippingbox.fill"
        case .boss: "crown.fill"
        }
    }

    var color: Color {
        switch self {
        case .combat: Color(red: 0.85, green: 0.35, blue: 0.3)
        case .elite: Color(red: 0.95, green: 0.55, blue: 0.15)
        case .event: Color(red: 0.55, green: 0.5, blue: 0.95)
        case .shop: Color(red: 0.95, green: 0.8, blue: 0.3)
        case .rest: Color(red: 0.35, green: 0.8, blue: 0.5)
        case .treasure: Color(red: 0.3, green: 0.75, blue: 0.95)
        case .boss: Color(red: 0.9, green: 0.15, blue: 0.25)
        }
    }
}

extension Rarity {
    var title: String {
        switch self {
        case .common: "Comune"
        case .rare: "Rara"
        case .legendary: "Leggendaria"
        }
    }

    var color: Color {
        switch self {
        case .common: Color(white: 0.75)
        case .rare: Color(red: 0.35, green: 0.6, blue: 1)
        case .legendary: Color(red: 1, green: 0.6, blue: 0.15)
        }
    }
}
