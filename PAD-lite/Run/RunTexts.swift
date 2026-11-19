import PADRoguelikeCore
import SwiftUI

// Italian UI texts and colors for core run types.

extension Element {
    var color: Color { Color(uiColor: orbType.baseColor) }
}

extension OrbType {
    var displayName: String { element?.displayName ?? "Cuore" }
}

extension NodeKind {
    var title: String {
        switch self {
        case .combat: "Combattimento"
        case .elite: "Elite"
        case .rest: "Riposo"
        case .treasure: "Tesoro"
        case .boss: "Boss"
        }
    }

    var summary: String {
        switch self {
        case .combat: "Nemici normali. Ricompensa: reliquia o livello"
        case .elite: "Un nemico forte. Ricompensa: reliquie rare"
        case .rest: "Recuperi parte degli HP"
        case .treasure: "Scegli una reliquia"
        case .boss: "Lo scontro finale"
        }
    }

    var symbol: String {
        switch self {
        case .combat: "burst.fill"
        case .elite: "star.circle.fill"
        case .rest: "bed.double.fill"
        case .treasure: "gift.fill"
        case .boss: "crown.fill"
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
        case .common: .gray
        case .rare: .blue
        case .legendary: .orange
        }
    }
}

private func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
private func times(_ value: Double) -> String { "×" + value.formatted(.number.precision(.fractionLength(0...2))) }
private func turns(_ count: Int) -> String { count == 1 ? "1 turno" : "\(count) turni" }

extension Modifier {
    var displayText: String {
        switch self {
        case let .flatDamage(element, amount):
            "+\(amount) attacco" + (element.map { " \($0.displayName)" } ?? "")
        case let .damageMultiplier(element, factor):
            "Danno" + (element.map { " \($0.displayName)" } ?? "") + " \(times(factor))"
        case let .comboBonus(amount):
            "+\(percent(amount)) per combo extra"
        case let .orbBonus(orb, amount):
            "+\(percent(amount)) per sfera extra" + (orb.map { " (\($0.displayName))" } ?? "")
        case let .flatHeal(amount):
            "+\(amount) cura"
        case let .healMultiplier(factor):
            "Cura \(times(factor))"
        case let .maxHPMultiplier(factor):
            "HP massimi \(times(factor))"
        case let .damageReduction(amount):
            "-\(percent(amount)) danni subiti"
        case let .shieldOnTurnStart(amount):
            "+\(amount) scudo a ogni turno"
        case let .healOnTurnStart(amount):
            "+\(amount) HP a ogni turno"
        case let .shieldOnCombo(minCombos, amount):
            "+\(amount) scudo con \(minCombos)+ combo"
        case let .damageOnCombo(minCombos, factor):
            "Danno \(times(factor)) con \(minCombos)+ combo"
        }
    }
}

extension AbilityEffect {
    var displayText: String {
        switch self {
        case let .damage(target, element, multiplier):
            "Danno \(element.displayName) \(times(multiplier)) a " + (target == .allEnemies ? "tutti i nemici" : "un nemico")
        case let .healPercent(fraction):
            "Cura il \(percent(fraction)) degli HP"
        case let .shield(amount):
            "+\(amount) scudo"
        case let .delayEnemies(count):
            "Ritarda i nemici di \(turns(count))"
        case let .buff(source, count):
            source.modifiers.map(\.displayText).joined(separator: ", ") + " per \(turns(count))"
        case let .convertOrbs(from, to):
            "Sfere \(from.displayName) → \(to.displayName)"
        case .refreshBoard:
            "Rigenera la griglia"
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
