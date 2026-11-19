import Foundation

public extension CharacterDefinition {
    static let standard: [CharacterDefinition] = [
        CharacterDefinition(
            id: "kael", name: "Kael", element: .fire, baseHP: 4_000, baseAttack: 900, baseRecovery: 250,
            talents: [
                PassiveTalent(id: "kael.ember", name: "Brace", unlockLevel: 1,
                              modifiers: [.flatDamage(element: .fire, amount: 100)]),
                PassiveTalent(id: "kael.fury", name: "Furia", unlockLevel: 3,
                              modifiers: [.damageOnCombo(minCombos: 4, factor: 1.2)]),
            ],
            abilities: [
                Ability(id: "kael.blast", name: "Esplosione", cooldown: 4,
                        effects: [.damage(target: .selectedEnemy, element: .fire, multiplier: 6)]),
            ]
        ),
        CharacterDefinition(
            id: "nerea", name: "Nerea", element: .water, baseHP: 4_200, baseAttack: 850, baseRecovery: 300,
            talents: [
                PassiveTalent(id: "nerea.tide", name: "Marea", unlockLevel: 1,
                              modifiers: [.orbBonus(orb: .water, amount: 0.1)]),
                PassiveTalent(id: "nerea.undertow", name: "Risacca", unlockLevel: 3,
                              modifiers: [.healOnTurnStart(150)]),
            ],
            abilities: [
                Ability(id: "nerea.wave", name: "Onda", cooldown: 5, effects: [.convertOrbs(from: .fire, to: .water)]),
            ]
        ),
        CharacterDefinition(
            id: "sylas", name: "Sylas", element: .wood, baseHP: 5_000, baseAttack: 750, baseRecovery: 250,
            talents: [
                PassiveTalent(id: "sylas.bark", name: "Corteccia", unlockLevel: 1,
                              modifiers: [.damageReduction(0.1)]),
                PassiveTalent(id: "sylas.roots", name: "Radici", unlockLevel: 3,
                              modifiers: [.shieldOnCombo(minCombos: 3, amount: 400)]),
            ],
            abilities: [
                Ability(id: "sylas.barrier", name: "Barriera", cooldown: 4, effects: [.shield(1_500)]),
            ]
        ),
        CharacterDefinition(
            id: "lumen", name: "Lumen", element: .light, baseHP: 3_800, baseAttack: 800, baseRecovery: 450,
            talents: [
                PassiveTalent(id: "lumen.grace", name: "Grazia", unlockLevel: 1,
                              modifiers: [.healMultiplier(1.25)]),
                PassiveTalent(id: "lumen.aura", name: "Aura", unlockLevel: 3,
                              modifiers: [.maxHPMultiplier(1.1)]),
            ],
            abilities: [
                Ability(id: "lumen.blessing", name: "Benedizione", cooldown: 5,
                        effects: [.healPercent(0.35), .convertOrbs(from: .dark, to: .heal)]),
            ]
        ),
        CharacterDefinition(
            id: "umbra", name: "Umbra", element: .dark, baseHP: 3_500, baseAttack: 1_000, baseRecovery: 200,
            talents: [
                PassiveTalent(id: "umbra.shade", name: "Ombra", unlockLevel: 1,
                              modifiers: [.comboBonus(0.05)]),
                PassiveTalent(id: "umbra.pact", name: "Patto", unlockLevel: 3,
                              modifiers: [.damageMultiplier(element: nil, factor: 1.1)]),
            ],
            abilities: [
                Ability(id: "umbra.eclipse", name: "Eclissi", cooldown: 3, charges: 2, hpCost: 300,
                        effects: [
                            .delayEnemies(turns: 1),
                            .buff(ModifierSource(name: "Eclissi",
                                                 modifiers: [.damageMultiplier(element: .dark, factor: 2)]),
                                  turns: 1),
                        ]),
            ]
        ),
    ]
}
