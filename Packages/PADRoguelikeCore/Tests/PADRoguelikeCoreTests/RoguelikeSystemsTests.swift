import Foundation
import Testing
@testable import PADRoguelikeCore

private func cluster(_ type: OrbType, orbs: Int = 3) -> MatchCluster {
    MatchCluster(type: type, positions: (0..<orbs).map { GridPosition(col: $0, row: 0) })
}

private func dummy(hp: Int = 100_000, attack: Int = 1_000, interval: Int = 1, element: Element = .light) -> Enemy {
    Enemy(id: 0, name: "Dummy", element: element, maxHP: hp, attackPower: attack, turnInterval: interval)
}

// MARK: - Relics & modifiers

@Suite struct ModifierTests {

    @Test func modifiersStackInFixedOrderRegardlessOfSourceOrder() {
        let sources = [
            ModifierSource(name: "A", modifiers: [.damageMultiplier(element: .fire, factor: 1.5)]),
            ModifierSource(name: "B", modifiers: [.flatDamage(element: nil, amount: 100)]),
            ModifierSource(name: "C", modifiers: [.comboBonus(0.25), .damageMultiplier(element: .water, factor: 9)]),
        ]
        let forward = ModifierResolver(sources: sources)
        let backward = ModifierResolver(sources: sources.reversed())

        // (1000 + 100) x 1 (3 orbs) x 1.5 (2 combos, 0.25 + 0.25) x 2 (fire vs wood) x 1.5
        let hit = forward.damage(attack: 1_000, element: .fire, cluster: cluster(.fire), comboCount: 2, defender: .wood)
        #expect(hit.value == 4_950)
        #expect(backward.damage(attack: 1_000, element: .fire, cluster: cluster(.fire), comboCount: 2, defender: .wood).value == 4_950)
        #expect(hit.applied.map(\.source) == ["A", "B", "C"])
    }

    @Test func shieldAndReductionAbsorbEnemyDamage() {
        let battle = BattleEngine(player: .test, enemies: [dummy()], modifiers: [
            ModifierSource(name: "Armor", modifiers: [.damageReduction(0.2)]),
            ModifierSource(name: "Oak", modifiers: [.shieldOnTurnStart(300)]),
        ])
        let report = battle.resolveTurn(clusters: [])
        #expect(report.shieldGained == 300)
        #expect(report.enemyAttacks.first?.blocked == 300)
        #expect(report.enemyAttacks.first?.damage == 500)
        #expect(battle.player.currentHP == 4_500)
        #expect(battle.shield == 0)
    }

    @Test func damageReductionIsCapped() {
        let resolver = ModifierResolver(sources: [ModifierSource(name: "X", modifiers: [.damageReduction(0.5), .damageReduction(0.5)])])
        #expect(resolver.incomingDamage(1_000).value == 250)
    }

    @Test func comboTriggersNeedEnoughCombos() {
        let crown = ModifierSource(name: "Crown", modifiers: [.shieldOnCombo(minCombos: 3, amount: 400),
                                                              .damageOnCombo(minCombos: 3, factor: 2)])
        let battle = BattleEngine(player: .test, enemies: [dummy(interval: 9)], modifiers: [crown])

        let two = battle.resolveTurn(clusters: [cluster(.fire), cluster(.fire)])
        #expect(two.shieldGained == 0)
        #expect(two.playerAttacks.map(\.damage) == [1_250, 1_250])

        // 1000 x 1.5 (3 combos) x 2 (trigger)
        let three = battle.resolveTurn(clusters: [cluster(.fire), cluster(.fire), cluster(.fire)])
        #expect(three.shieldGained == 400)
        #expect(three.playerAttacks.map(\.damage) == [3_000, 3_000, 3_000])
    }

    @Test func healModifiersApply() {
        let battle = BattleEngine(player: Player(maxHP: 5_000, attack: [:], recovery: 300, currentHP: 1_000),
                                  enemies: [dummy(interval: 9)],
                                  modifiers: [ModifierSource(name: "Chalice", modifiers: [.flatHeal(50), .healMultiplier(1.5)])])
        #expect(battle.resolveTurn(clusters: [cluster(.heal)]).healed == 525)
    }
}

// MARK: - Abilities

@Suite struct AbilityTests {

    @Test func cooldownCountsPlayerMoves() throws {
        let barrier = Ability(id: "b", name: "Barrier", cooldown: 2, effects: [.shield(500)])
        let battle = BattleEngine(player: .test, enemies: [dummy(interval: 9)],
                                  abilities: [AbilityState(ability: barrier, owner: "Sylas")])

        #expect(try battle.useAbility(0).shieldGained == 500)
        #expect(throws: AbilityError.onCooldown) { try battle.useAbility(0) }
        _ = battle.resolveTurn(clusters: [])
        #expect(throws: AbilityError.onCooldown) { try battle.useAbility(0) }
        _ = battle.resolveTurn(clusters: [])
        #expect(battle.abilities[0].isReady)
        _ = try battle.useAbility(0)
    }

    @Test func chargesAndHPCost() throws {
        let pact = Ability(id: "p", name: "Pact", cooldown: 0, charges: 1, hpCost: 4_999, effects: [.shield(1)])
        let cheap = Ability(id: "c", name: "Cheap", cooldown: 0, hpCost: 1, effects: [.shield(1)])
        let battle = BattleEngine(player: .test, enemies: [dummy()],
                                  abilities: [AbilityState(ability: pact, owner: "A"), AbilityState(ability: cheap, owner: "B")])

        _ = try battle.useAbility(0)
        #expect(battle.player.currentHP == 1)
        #expect(throws: AbilityError.noCharges) { try battle.useAbility(0) }
        #expect(throws: AbilityError.notEnoughHP) { try battle.useAbility(1) }
        #expect(throws: AbilityError.invalidIndex) { try battle.useAbility(7) }
    }

    @Test func damageDelayAndTimedBuff() throws {
        let eclipse = Ability(id: "e", name: "Eclipse", cooldown: 5, effects: [
            .damage(target: .allEnemies, element: .fire, multiplier: 1),
            .delayEnemies(turns: 1),
            .buff(ModifierSource(name: "Eclipse", modifiers: [.damageMultiplier(element: .dark, factor: 2)]), turns: 1),
        ])
        let battle = BattleEngine(player: .test, enemies: Enemy.testRoster,
                                  abilities: [AbilityState(ability: eclipse, owner: "Umbra")])

        let report = try battle.useAbility(0)
        #expect(report.attacks.map(\.damage) == [2_000, 500, 1_000])
        #expect(report.delayedEnemies == [1, 2])

        let buffed = battle.resolveTurn(clusters: [cluster(.dark)])
        #expect(buffed.playerAttacks.first?.damage == 1_600)
        #expect(buffed.appliedModifiers.map(\.source) == ["Eclipse"])
        #expect(buffed.enemyAttacks.isEmpty)

        #expect(battle.resolveTurn(clusters: [cluster(.dark)]).playerAttacks.first?.damage == 800)
    }

    @Test func boardAbilitiesConvertOrbs() throws {
        let wave = Ability(id: "w", name: "Wave", cooldown: 1, effects: [.convertOrbs(from: .fire, to: .water)])
        let battle = BattleEngine(player: .test, enemies: [dummy()], abilities: [AbilityState(ability: wave, owner: "Nerea")])
        let board = BoardEngine(layout: [
            [.fire, .water, .wood],
            [.wood, .fire, .water],
            [.water, .wood, .fire],
        ])

        #expect(throws: AbilityError.needsBoard) { try battle.useAbility(0) }
        let report = try battle.useAbility(0, board: board)
        #expect(report.conversions.count == 3)
        #expect(board.grid.joined().allSatisfy { $0?.type != .fire })
    }
}

// MARK: - Characters

@Suite struct CharacterTests {

    private func character(_ id: String) throws -> CharacterDefinition {
        try #require(GameCatalog.standard.character(id: id))
    }

    @Test func statsGrowWithLevelAndTalentsUnlock() throws {
        let nerea = try character("nerea")
        let player = nerea.makePlayer(level: 3)
        #expect(player.maxHP == 5_040)
        #expect(Set(player.attack.values) == [1_020])
        #expect(nerea.modifierSources(at: 1).map(\.name) == ["Nerea: Affinità", "Nerea: Marea"])
        #expect(nerea.modifierSources(at: 3).map(\.name) == ["Nerea: Affinità", "Nerea: Marea", "Nerea: Risacca"])
        #expect(nerea.abilityStates.map(\.owner) == ["Nerea"])
    }

    @Test func ownElementGetsAffinityBonus() throws {
        let kael = try character("kael")
        let resolver = ModifierResolver(sources: kael.modifierSources(at: 1))
        let attack = kael.makePlayer(level: 1).attack[.fire] ?? 0
        // (900 + 100 Brace) x 1.5 affinity
        #expect(resolver.damage(attack: attack, element: .fire, cluster: cluster(.fire), comboCount: 1, defender: .light).value == 1_500)
        #expect(resolver.damage(attack: attack, element: .water, cluster: cluster(.water), comboCount: 1, defender: .light).value == 900)
    }

    @Test func talentsCanRaiseMaxHP() throws {
        let lumen = try character("lumen")
        let player = lumen.makePlayer(level: 3, resolver: ModifierResolver(sources: lumen.modifierSources(at: 3)), missingHP: 100)
        #expect(player.maxHP == 5_016)
        #expect(player.currentHP == 4_916)
    }
}

// MARK: - Run

/// Tiny map with trivial enemies, to test run flow through the `RunRules` hooks.
private struct ScriptedRules: RunRules {
    var enemyHP = 1
    var enemyAttack = 100
    let floorCount = 3
    let restHealFraction = 0.5

    func nodeChoices(floor: Int, rng: inout SeededRandom) -> [NodeKind] {
        [[.combat], [.rest, .treasure], [.boss]][floor]
    }

    func encounter(floor: Int, kind: NodeKind, catalog: GameCatalog, rng: inout SeededRandom) -> Encounter {
        Encounter(kind: kind, mode: .simultaneous, enemies: [
            Enemy(id: 0, name: "Dummy", element: .light, maxHP: enemyHP(base: 0, floor: floor, kind: kind),
                  attackPower: enemyAttack(base: 0, floor: floor, kind: kind), turnInterval: 1),
        ])
    }

    func enemyHP(base: Int, floor: Int, kind: NodeKind) -> Int { enemyHP }
    func enemyAttack(base: Int, floor: Int, kind: NodeKind) -> Int { enemyAttack }

    func rewards(after kind: NodeKind, floor: Int, state: RunState, catalog: GameCatalog,
                 rng: inout SeededRandom) -> [Reward] {
        switch kind {
        case .combat: [.relic(id: "prism"), .levelUp]
        case .treasure: [.relic(id: "giant-heart")]
        default: []
        }
    }
}

@Suite struct RunTests {

    @Test func fullRunThroughNodesRewardsAndBoss() throws {
        let run = RunEngine(seed: 1, characterID: "kael", rules: ScriptedRules())
        #expect(throws: RunError.wrongPhase) { try run.makeBattle() }

        try run.chooseNode(0)
        let battle = try run.makeBattle()
        #expect(battle.abilities.map(\.ability.name) == ["Esplosione"])
        _ = battle.resolveTurn(clusters: [cluster(.fire)])
        try run.finishBattle(battle)
        #expect(run.state.phase == .choosingReward([.relic(id: "prism"), .levelUp]))

        try run.chooseReward(1)
        #expect(run.state.characterLevel == 2)
        #expect(run.state.phase == .choosingNode([.rest, .treasure]))

        try run.chooseNode(1)
        try run.chooseReward(0)
        #expect(run.relics.map(\.name) == ["Cuore di Gigante"])
        // 4000 x 1.1 (level 2) x 1.25 (relic)
        #expect(run.makePlayer().maxHP == 5_500)

        try run.chooseNode(0)
        let boss = try run.makeBattle()
        _ = boss.resolveTurn(clusters: [cluster(.fire)])
        try run.finishBattle(boss)
        #expect(run.state.phase == .won)
    }

    @Test func defeatEndsTheRun() throws {
        let run = RunEngine(seed: 1, characterID: "kael",
                            rules: ScriptedRules(enemyHP: 1_000_000, enemyAttack: 1_000_000))
        try run.chooseNode(0)
        let battle = try run.makeBattle()
        _ = battle.resolveTurn(clusters: [])
        try run.finishBattle(battle)
        #expect(run.state.phase == .lost)
    }

    @Test func damageCarriesOverAndRestHeals() throws {
        var rules = ScriptedRules()
        rules.enemyHP = 2_600
        let run = RunEngine(seed: 1, characterID: "kael", rules: rules)
        try run.chooseNode(0)
        let battle = try run.makeBattle()
        _ = battle.resolveTurn(clusters: [])
        // (900 + 100 Brace) x 1.75 (6 orbs) x 1.5 (affinity) = 2625
        _ = battle.resolveTurn(clusters: [cluster(.fire, orbs: 6)])
        try run.finishBattle(battle)
        #expect(run.state.missingHP == 100)
        #expect(run.makePlayer().currentHP == 3_900)

        try run.chooseReward(nil)
        try run.chooseNode(0)
        #expect(run.state.missingHP == 0)
    }

    @Test func sameSeedSameRunAndSaveRestoresExactly() throws {
        let a = RunEngine(seed: 42, characterID: "kael")
        let b = RunEngine(seed: 42, characterID: "kael")
        try a.chooseNode(0)
        try b.chooseNode(0)
        #expect(a.state == b.state)

        let data = try JSONEncoder().encode(a.state)
        let restored = RunEngine(restoring: try JSONDecoder().decode(RunState.self, from: data))
        #expect(restored.state == a.state)

        for run in [a, restored] {
            let battle = try run.makeBattle()
            while battle.outcome == .ongoing {
                _ = battle.resolveTurn(clusters: [cluster(.fire, orbs: 6), cluster(.water, orbs: 6), cluster(.heal)])
            }
            try run.finishBattle(battle)
        }
        #expect(restored.state == a.state)
    }

    @Test func standardRulesShape() {
        let rules = StandardRunRules()
        var rng = SeededRandom(seed: 7)
        #expect(rules.nodeChoices(floor: 0, rng: &rng) == [.combat])
        #expect(rules.nodeChoices(floor: rules.floorCount - 1, rng: &rng) == [.boss])
        let middle = rules.nodeChoices(floor: 3, rng: &rng)
        #expect(middle.count == 3 && Set(middle.map(\.rawValue)).count == 3)
        #expect(rules.enemyHP(base: 1_000, floor: 5, kind: .combat) == 2_000)
        #expect(rules.encounter(floor: 4, kind: .combat, catalog: .standard, rng: &rng).enemies.count == 3)
        #expect(rules.encounter(floor: 7, kind: .boss, catalog: .standard, rng: &rng).enemies.count == 1)
    }
}
