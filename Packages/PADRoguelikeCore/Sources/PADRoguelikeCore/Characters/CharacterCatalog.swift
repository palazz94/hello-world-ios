import Foundation

public extension CharacterDefinition {
    /// Each hero rewards a different way of moving orbs.
    static let standard: [CharacterDefinition] = [
        CharacterDefinition(
            id: "kael", name: "Kael", element: .fire, title: "Il Ritmo",
            playstyle: "Tante combo piccole: più combo fai, più cresce.",
            baseHP: 4_200, baseAttack: 1_000, baseRecovery: 250,
            talents: [
                PassiveTalent(id: "kael.rhythm", name: "Ritmo", unlockLevel: 1, modifiers: [.comboBonus(0.1)]),
                PassiveTalent(id: "kael.crescendo", name: "Crescendo", unlockLevel: 3,
                              modifiers: [.turnDamage(.combosAtLeast(6), factor: 1.5)]),
                PassiveTalent(id: "kael.inferno", name: "Inferno", unlockLevel: 5,
                              modifiers: [.turnDamage(.combosAtLeast(8), factor: 2.0)]),
            ],
            abilities: [
                Ability(id: "kael.blast", name: "Esplosione", cooldown: 5,
                        effects: [.damage(target: .selectedEnemy, element: .fire, multiplier: 8)]),
            ]
        ),
        CharacterDefinition(
            id: "nerea", name: "Nerea", element: .water, title: "La Geometra",
            playstyle: "Match da esattamente 4 sfere valgono moltissimo.",
            baseHP: 4_000, baseAttack: 950, baseRecovery: 300,
            talents: [
                PassiveTalent(id: "nerea.square", name: "Quadrato", unlockLevel: 1,
                              modifiers: [.clusterDamage(.orbsExactly(4), element: nil, factor: 1.6)]),
                PassiveTalent(id: "nerea.tide", name: "Onda Quadra", unlockLevel: 3,
                              modifiers: [.clusterDamage(.orbsExactly(4), element: .water, factor: 1.8)]),
                PassiveTalent(id: "nerea.calm", name: "Calma Piatta", unlockLevel: 5,
                              modifiers: [.turnHeal(.combosAtLeast(3), amount: 350),
                                          .clusterDamage(.orbsExactly(4), element: nil, factor: 1.3)]),
            ],
            abilities: [
                Ability(id: "nerea.wave", name: "Onda", cooldown: 5, effects: [.convertOrbs(from: .fire, to: .water)]),
            ]
        ),
        CharacterDefinition(
            id: "sylas", name: "Sylas", element: .wood, title: "Il Colosso",
            playstyle: "Pochi match enormi (5+ sfere) e tanto scudo.",
            baseHP: 5_200, baseAttack: 850, baseRecovery: 250,
            talents: [
                PassiveTalent(id: "sylas.roots", name: "Radici Larghe", unlockLevel: 1,
                              modifiers: [.clusterDamage(.orbsAtLeast(5), element: nil, factor: 1.7)]),
                PassiveTalent(id: "sylas.bark", name: "Corteccia", unlockLevel: 3,
                              modifiers: [.turnShield(.orbsAtLeast(15), amount: 600)]),
                PassiveTalent(id: "sylas.forest", name: "Foresta", unlockLevel: 5,
                              modifiers: [.clusterDamage(.orbsAtLeast(6), element: nil, factor: 1.6)]),
            ],
            abilities: [
                Ability(id: "sylas.sprout", name: "Germoglio", cooldown: 6,
                        effects: [.convertOrbs(from: .light, to: .wood), .shield(800)]),
            ]
        ),
        CharacterDefinition(
            id: "lumen", name: "Lumen", element: .light, title: "L'Iride",
            playstyle: "Colpisce forte quando abbini tanti colori diversi.",
            baseHP: 3_800, baseAttack: 950, baseRecovery: 450,
            talents: [
                PassiveTalent(id: "lumen.spectrum", name: "Spettro", unlockLevel: 1,
                              modifiers: [.turnDamage(.colorsAtLeast(4), factor: 1.7)]),
                PassiveTalent(id: "lumen.aurora", name: "Aurora", unlockLevel: 3,
                              modifiers: [.turnHeal(.colorsAtLeast(5), amount: 500)]),
                PassiveTalent(id: "lumen.rainbow", name: "Arcobaleno", unlockLevel: 5,
                              modifiers: [.turnDamage(.colorsAtLeast(6), factor: 2.0)]),
            ],
            abilities: [
                Ability(id: "lumen.rebirth", name: "Rinascita", cooldown: 6,
                        effects: [.refreshBoard, .healPercent(0.15)]),
            ]
        ),
        CharacterDefinition(
            id: "umbra", name: "Umbra", element: .dark, title: "La Berserker",
            playstyle: "Più è ferita, più fa male. Gioca sul filo.",
            baseHP: 3_400, baseAttack: 1_150, baseRecovery: 150,
            talents: [
                PassiveTalent(id: "umbra.thirst", name: "Sete", unlockLevel: 1,
                              modifiers: [.turnDamage(.hpBelow(0.5), factor: 1.7)]),
                PassiveTalent(id: "umbra.pact", name: "Patto", unlockLevel: 3,
                              modifiers: [.damageMultiplier(element: nil, factor: 1.25), .hpLossOnTurnStart(80)]),
                PassiveTalent(id: "umbra.last-breath", name: "Ultimo Respiro", unlockLevel: 5,
                              modifiers: [.turnDamage(.hpBelow(0.25), factor: 2.0)]),
            ],
            abilities: [
                Ability(id: "umbra.eclipse", name: "Eclissi", cooldown: 4, hpCost: 500,
                        effects: [.damage(target: .allEnemies, element: .dark, multiplier: 4), .delayEnemies(turns: 1)]),
            ]
        ),
        CharacterDefinition(
            id: "mira", name: "Mira", element: .fire, title: "La Gemella",
            playstyle: "Abbina fuoco e luce nella stessa mossa.",
            baseHP: 3_900, baseAttack: 1_000, baseRecovery: 300,
            talents: [
                PassiveTalent(id: "mira.twin-flame", name: "Doppia Fiamma", unlockLevel: 1,
                              modifiers: [.turnDamage(.matched([.fire, .light]), factor: 1.8)]),
                PassiveTalent(id: "mira.echo", name: "Eco", unlockLevel: 3,
                              modifiers: [.clusterDamage(.orbsAtLeast(4), element: .light, factor: 1.4)]),
                PassiveTalent(id: "mira.supernova", name: "Supernova", unlockLevel: 5,
                              modifiers: [.turnShield(.matched([.fire, .light]), amount: 500),
                                          .turnDamage(.matched([.fire, .light, .heal]), factor: 1.4)]),
            ],
            abilities: [
                Ability(id: "mira.spark", name: "Scintilla", cooldown: 6,
                        effects: [.convertOrbs(from: .wood, to: .fire), .convertOrbs(from: .dark, to: .light)]),
            ]
        ),
    ]
}
