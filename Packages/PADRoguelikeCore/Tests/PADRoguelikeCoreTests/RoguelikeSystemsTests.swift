import Foundation
import Testing
@testable import PADRoguelikeCore

private func cluster(_ type: OrbType, orbs: Int = 3) -> MatchCluster {
    MatchCluster(type: type, positions: (0..<orbs).map { GridPosition(col: $0, row: 0) })
}

private func dummy(hp: Int = 100_000, attack: Int = 1_000, interval: Int = 1, element: Element = .light,
                   traits: [EnemyTrait] = []) -> Enemy {
    Enemy(id: 0, name: "Dummy", element: element, maxHP: hp, attackPower: attack, turnInterval: interval, traits: traits)
}

private func source(_ modifiers: Modifier...) -> ModifierSource {
    ModifierSource(name: "Test", modifiers: modifiers)
}

// MARK: - Modifiers

@Suite struct ModifierTests {

    @Test func modifiersStackInFixedOrderRegardlessOfSourceOrder() {
        let sources = [
            ModifierSource(name: "A", modifiers: [.damageMultiplier(element: .fire, factor: 1.5)]),
            ModifierSource(name: "B", modifiers: [.flatDamage(element: nil, amount: 100)]),
            ModifierSource(name: "C", modifiers: [.comboBonus(0.25), .damageMultiplier(element: .water, factor: 9)]),
        ]
        let turn = TurnContext(clusters: [cluster(.fire), cluster(.fire)])
        // (1000 + 100) x 1 (3 orbs) x 1.5 (2 combos, 0.25 + 0.25) x 2 (fire vs wood) x 1.5
        let hit = ModifierResolver(sources: sources).damage(attack: 1_000, element: .fire, cluster: cluster(.fire),
                                                            turn: turn, defender: .wood)
        let reversed = ModifierResolver(sources: sources.reversed()).damage(attack: 1_000, element: .fire,
                                                                           cluster: cluster(.fire), turn: turn, defender: .wood)
        #expect(hit.value == 4_950)
        #expect(reversed.value == 4_950)
        #expect(hit.applied.map(\.source) == ["A", "B", "C"])
    }

    @Test func clusterConditionsRewardSpecificMatchSizes() {
        let resolver = ModifierResolver(sources: [source(.clusterDamage(.orbsExactly(4), element: nil, factor: 2))])
        let four = cluster(.fire, orbs: 4)
        let five = cluster(.fire, orbs: 5)
        #expect(resolver.damage(attack: 1_000, element: .fire, cluster: four, turn: TurnContext(clusters: [four]),
                                defender: .light).value == 2_500)
        #expect(resolver.damage(attack: 1_000, element: .fire, cluster: five, turn: TurnContext(clusters: [five]),
                                defender: .light).value == 1_500)
    }

    @Test func matchedColorsCondition() {
        let resolver = ModifierResolver(sources: [source(.turnDamage(.matched([.fire, .water]), factor: 2))])
        let both = TurnContext(clusters: [cluster(.fire), cluster(.water)])
        let onlyFire = TurnContext(clusters: [cluster(.fire), cluster(.fire)])
        #expect(resolver.damage(attack: 1_000, element: .fire, cluster: cluster(.fire), turn: both, defender: .light).value == 2_500)
        #expect(resolver.damage(attack: 1_000, element: .fire, cluster: cluster(.fire), turn: onlyFire, defender: .light).value == 1_250)
        #expect(both.colors.count == 2)
    }

    @Test func lowHPRiskRewardAndNonLethalDrain() {
        let battle = BattleEngine(player: Player(maxHP: 5_000, attack: [.fire: 1_000], recovery: 0, currentHP: 1_000),
                                  enemies: [dummy(interval: 9)],
                                  modifiers: [source(.turnDamage(.hpBelow(0.5), factor: 2), .hpLossOnTurnStart(300))])
        let report = battle.resolveTurn(clusters: [cluster(.fire)])
        #expect(report.playerAttacks.first?.damage == 2_000)
        #expect(report.selfDamage == 300)
        #expect(battle.player.currentHP == 700)

        let fragile = BattleEngine(player: Player(maxHP: 5_000, attack: [:], recovery: 0, currentHP: 100),
                                   enemies: [dummy(interval: 9)], modifiers: [source(.hpLossOnTurnStart(300))])
        _ = fragile.resolveTurn(clusters: [])
        #expect(fragile.player.currentHP == 1)
    }

    @Test func moveConditionsTriggerAfterTheMove() {
        let battle = BattleEngine(player: .test, enemies: [dummy(interval: 9)], modifiers: [
            source(.turnShield(.combosAtLeast(3), amount: 400), .turnDamage(.combosAtLeast(3), factor: 2),
                   .turnSelfDamage(.combosAtMost(1), amount: 250)),
        ])
        let single = battle.resolveTurn(clusters: [cluster(.fire)])
        #expect(single.selfDamage == 250)
        #expect(single.shieldGained == 0)

        // 1000 x 1.5 (3 combos) x 2 (trigger)
        let three = battle.resolveTurn(clusters: [cluster(.fire), cluster(.fire), cluster(.fire)])
        #expect(three.shieldGained == 400)
        #expect(three.selfDamage == 0)
        #expect(three.playerAttacks.map(\.damage) == [3_000, 3_000, 3_000])
    }

    @Test func defensiveModifiersAndDrawbacks() {
        let battle = BattleEngine(player: .test, enemies: [dummy()], modifiers: [
            source(.damageReduction(0.2), .shieldOnTurnStart(300)),
        ])
        let report = battle.resolveTurn(clusters: [])
        #expect(report.enemyAttacks.first?.blocked == 300)
        #expect(report.enemyAttacks.first?.damage == 500)

        let risky = ModifierResolver(sources: [source(.damageReduction(0.2), .damageTakenMultiplier(1.5))])
        #expect(risky.incomingDamage(1_000).value == 1_200)
        let capped = ModifierResolver(sources: [source(.damageReduction(0.5), .damageReduction(0.5))])
        #expect(capped.incomingDamage(1_000).value == 250)
    }

    @Test func healAndMoveTime() {
        let battle = BattleEngine(player: Player(maxHP: 5_000, attack: [:], recovery: 300, currentHP: 1_000),
                                  enemies: [dummy(interval: 9)],
                                  modifiers: [source(.flatHeal(50), .healMultiplier(1.5))])
        #expect(battle.resolveTurn(clusters: [cluster(.heal)]).healed == 525)
        #expect(ModifierResolver(sources: [source(.moveTime(1.5), .moveTime(-0.5))]).moveTimeBonus() == 1)
    }
}

// MARK: - Enemy traits

@Suite struct EnemyTraitTests {

    @Test func comboShieldNeedsEnoughCombos() {
        let battle = BattleEngine(player: .test, enemies: [dummy(interval: 9, traits: [.comboShield(minCombos: 3)])])
        let two = battle.resolveTurn(clusters: [cluster(.fire), cluster(.fire)])
        #expect(two.playerAttacks.allSatisfy { $0.block == .comboShield && $0.damage == 0 })
        #expect(battle.enemies[0].currentHP == 100_000)
        _ = battle.resolveTurn(clusters: [cluster(.fire), cluster(.fire), cluster(.fire)])
        #expect(battle.enemies[0].currentHP < 100_000)
    }

    @Test func absorbHealsArmorReducesRegenerateRecovers() {
        let absorber = BattleEngine(player: .test, enemies: [dummy(interval: 9, traits: [.absorb(.fire)])])
        _ = absorber.resolveTurn(clusters: [cluster(.water)])
        #expect(absorber.enemies[0].currentHP == 99_000)
        let absorbed = absorber.resolveTurn(clusters: [cluster(.fire)])
        #expect(absorbed.playerAttacks.first?.block == .absorbed)
        #expect(absorber.enemies[0].currentHP == 100_000)

        let armored = BattleEngine(player: .test, enemies: [dummy(interval: 9, traits: [.armor(300)])])
        #expect(armored.resolveTurn(clusters: [cluster(.fire)]).playerAttacks.first?.damage == 700)

        let regen = BattleEngine(player: .test, enemies: [dummy(hp: 10_000, interval: 9, traits: [.regenerate(0.1)])])
        _ = regen.resolveTurn(clusters: [cluster(.fire)])
        #expect(regen.enemies[0].currentHP == 10_000)
    }

    @Test func enrageGrowsAttack() {
        let battle = BattleEngine(player: .test, enemies: [dummy(traits: [.enrage(0.5)])])
        #expect(battle.resolveTurn(clusters: []).enemyAttacks.first?.damage == 1_000)
        #expect(battle.resolveTurn(clusters: []).enemyAttacks.first?.damage == 1_500)
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

    @Test func abilitiesIgnoreComboShield() throws {
        let blast = Ability(id: "x", name: "Blast", cooldown: 1, effects: [.damage(target: .selectedEnemy, element: .fire, multiplier: 1)])
        let battle = BattleEngine(player: .test, enemies: [dummy(traits: [.comboShield(minCombos: 9)])],
                                  abilities: [AbilityState(ability: blast, owner: "K")])
        #expect(try battle.useAbility(0).attacks.first?.damage == 1_000)
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
        #expect(player.maxHP == 4_800)
        #expect(Set(player.attack.values) == [1_140])
        #expect(nerea.modifierSources(at: 1).map(\.name) == ["Nerea: Affinità", "Nerea: Quadrato"])
        #expect(nerea.modifierSources(at: 3).map(\.name) == ["Nerea: Affinità", "Nerea: Quadrato", "Nerea: Onda Quadra"])
        #expect(nerea.abilityStates.map(\.owner) == ["Nerea"])
    }

    @Test func ownElementGetsAffinityBonus() throws {
        let kael = try character("kael")
        let resolver = ModifierResolver(sources: kael.modifierSources(at: 1))
        let attack = kael.makePlayer(level: 1).attack[.fire] ?? 0
        let turn = TurnContext(clusters: [cluster(.fire)])
        #expect(resolver.damage(attack: attack, element: .fire, cluster: cluster(.fire), turn: turn, defender: .light).value == 1_500)
        #expect(resolver.damage(attack: attack, element: .water, cluster: cluster(.water), turn: turn, defender: .light).value == 1_000)
    }

    @Test func heroesRewardDifferentPlaystyles() throws {
        let nerea = try character("nerea")
        let four = cluster(.water, orbs: 4)
        // 950 x 1.25 (4 orbs) x 1.5 (affinity) x 1.6 (Quadrato)
        #expect(ModifierResolver(sources: nerea.modifierSources(at: 1))
            .damage(attack: 950, element: .water, cluster: four, turn: TurnContext(clusters: [four]), defender: .light).value == 2_850)
        #expect(Set(GameCatalog.standard.characters.map(\.playstyle)).count == GameCatalog.standard.characters.count)
    }
}

// MARK: - Run

/// Tiny fixed map to test run flow through the `RunRules` hooks:
/// 0 combat -> (1 event | 2 shop) -> 3 rest -> 4 treasure -> 5 boss.
private struct ScriptedRules: RunRules {
    var enemyHP = 1
    var enemyAttack = 100
    var eventID = "fountain"
    var combatGold = 50
    let restHealFraction = 0.5

    func makeMap(rng: inout SeededRandom) -> RunMap {
        RunMap(columns: 3, nodes: [
            MapNode(id: 0, row: 0, column: 1, kind: .combat, next: [1, 2]),
            MapNode(id: 1, row: 1, column: 0, kind: .event, next: [3]),
            MapNode(id: 2, row: 1, column: 2, kind: .shop, next: [3]),
            MapNode(id: 3, row: 2, column: 1, kind: .rest, next: [4]),
            MapNode(id: 4, row: 3, column: 1, kind: .treasure, next: [5]),
            MapNode(id: 5, row: 4, column: 1, kind: .boss, next: []),
        ])
    }

    func encounter(row: Int, kind: NodeKind, catalog: GameCatalog, rng: inout SeededRandom) -> Encounter {
        Encounter(kind: kind, mode: .simultaneous, enemies: [
            Enemy(id: 0, name: "Dummy", element: .light, maxHP: enemyHP, attackPower: enemyAttack, turnInterval: 1),
        ])
    }

    func enemyHP(base: Int, row: Int, kind: NodeKind) -> Int { enemyHP }
    func enemyAttack(base: Int, row: Int, kind: NodeKind) -> Int { enemyAttack }
    func gold(after kind: NodeKind, rng: inout SeededRandom) -> Int { combatGold }

    func rewards(after kind: NodeKind, state: RunState, catalog: GameCatalog, rng: inout SeededRandom) -> [Reward] {
        switch kind {
        case .combat: [.relic(id: "metronome"), .levelUp, .gold(35)]
        case .treasure: [.relic(id: "glass-heart")]
        default: []
        }
    }

    func shop(state: RunState, catalog: GameCatalog, rng: inout SeededRandom) -> [ShopItem] {
        [ShopItem(reward: .relic(id: "hourglass"), price: 30), ShopItem(reward: .levelUp, price: 100)]
    }

    func event(state: RunState, catalog: GameCatalog, rng: inout SeededRandom) -> RunEvent {
        catalog.events.first { $0.id == eventID } ?? catalog.events[0]
    }
}

@Suite struct RunTests {

    private func winFight(_ run: RunEngine) throws {
        let battle = try run.makeBattle()
        _ = battle.resolveTurn(clusters: [cluster(.fire)])
        try run.finishBattle(battle)
    }

    @Test func fullRunThroughEveryRoomKind() throws {
        let run = RunEngine(seed: 1, characterID: "kael", rules: ScriptedRules())
        #expect(run.reachableNodes.map(\.id) == [0])
        #expect(throws: RunError.invalidChoice) { try run.travel(to: 3) }

        try run.travel(to: 0)
        #expect(throws: RunError.wrongPhase) { try run.travel(to: 1) }
        try winFight(run)
        #expect(run.state.gold == 50)
        #expect(run.state.phase == .choosingReward([.relic(id: "metronome"), .levelUp, .gold(35)]))
        try run.chooseReward(1)
        #expect(run.state.characterLevel == 2)
        #expect(run.reachableNodes.map(\.id) == [1, 2])

        try run.travel(to: 2)
        #expect(throws: RunError.notEnoughGold) { try run.buy(1) }
        try run.buy(0)
        #expect(run.state.gold == 20)
        #expect(throws: RunError.invalidChoice) { try run.buy(0) }
        try run.leaveShop()

        try run.travel(to: 3)
        try run.rest(.train)
        #expect(run.state.characterLevel == 3)

        try run.travel(to: 4)
        try run.chooseReward(0)
        #expect(run.relics.map(\.name) == ["Clessidra", "Cuore di Vetro"])
        // 4200 x 1.2 (level 3) x 0.7 (Cuore di Vetro)
        #expect(run.makePlayer().maxHP == 3_528)
        #expect(run.resolver.moveTimeBonus() == 1.5)

        try run.travel(to: 5)
        try winFight(run)
        #expect(run.state.phase == .won)
        #expect(run.state.path == [0, 2, 3, 4, 5])
    }

    @Test func eventsTradeGoldAndCanStartFights() throws {
        let run = RunEngine(seed: 1, characterID: "kael", rules: ScriptedRules())
        try run.travel(to: 0)
        try winFight(run)
        try run.chooseReward(nil)
        try run.travel(to: 1)
        #expect(run.currentEvent?.title == "Fontana Antica")
        try run.chooseEventOption(1)
        #expect(run.state.gold == 10)
        #expect(run.state.characterLevel == 2)
        #expect(run.state.phase == .map)

        var gambling = ScriptedRules()
        gambling.eventID = "gambler"
        let duel = RunEngine(seed: 1, characterID: "kael", rules: gambling)
        try duel.travel(to: 0)
        try winFight(duel)
        try duel.chooseReward(nil)
        try duel.travel(to: 1)
        #expect(throws: RunError.notEnoughGold) { try duel.chooseEventOption(0) }
        try duel.chooseEventOption(1)
        #expect(duel.state.gold == 90)
        guard case .inCombat = duel.state.phase else {
            Issue.record("The duel should start a fight")
            return
        }
    }

    @Test func defeatEndsTheRun() throws {
        let run = RunEngine(seed: 1, characterID: "kael",
                            rules: ScriptedRules(enemyHP: 1_000_000, enemyAttack: 1_000_000))
        try run.travel(to: 0)
        let battle = try run.makeBattle()
        _ = battle.resolveTurn(clusters: [])
        try run.finishBattle(battle)
        #expect(run.state.phase == .lost)
    }

    @Test func damageCarriesOverAndRestHeals() throws {
        var rules = ScriptedRules()
        rules.enemyHP = 2_600
        let run = RunEngine(seed: 1, characterID: "kael", rules: rules)
        try run.travel(to: 0)
        let battle = try run.makeBattle()
        _ = battle.resolveTurn(clusters: [])
        // 1000 x 1.75 (6 orbs) x 1.5 (affinity) = 2625
        _ = battle.resolveTurn(clusters: [cluster(.fire, orbs: 6)])
        try run.finishBattle(battle)
        #expect(run.state.missingHP == 100)
        #expect(run.makePlayer().currentHP == 4_100)

        try run.chooseReward(nil)
        try run.travel(to: 2)
        try run.leaveShop()
        try run.travel(to: 3)
        try run.rest(.heal)
        #expect(run.state.missingHP == 0)
    }

    @Test func sameSeedSameRunAndSaveRestoresExactly() throws {
        let a = RunEngine(seed: 42, characterID: "kael")
        let b = RunEngine(seed: 42, characterID: "kael")
        #expect(a.state == b.state)
        let first = try #require(a.reachableNodes.first?.id)
        try a.travel(to: first)
        try b.travel(to: first)
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

    @Test(arguments: 1...25)
    func standardMapIsAWellFormedSpire(seed: UInt64) {
        let rules = StandardRunRules()
        var rng = SeededRandom(seed: seed)
        let map = rules.makeMap(rng: &rng)

        #expect(map.rowCount == rules.rows + 1)
        #expect(map.nodes.filter { $0.kind == .boss }.count == 1)
        #expect(map.nodes(inRow: 0).allSatisfy { $0.kind == .combat })
        #expect(map.nodes(inRow: rules.rows / 2).allSatisfy { $0.kind == .treasure })
        #expect(map.nodes(inRow: rules.rows - 1).allSatisfy { $0.kind == .rest })
        #expect(Set(map.nodes(inRow: 0).map(\.column)).count >= 2)

        for node in map.nodes where node.kind != .boss {
            #expect(!node.next.isEmpty)
            for next in node.next.compactMap(map.node) {
                #expect(next.row == node.row + 1)
                #expect(node.kind != next.kind || ![.elite, .shop, .rest].contains(node.kind))
            }
        }
        for node in map.nodes where node.row > 0 {
            #expect(map.nodes.contains { $0.next.contains(node.id) })
        }
        for row in 0..<(rules.rows - 1) {
            let edges = map.nodes(inRow: row).flatMap { node in
                node.next.compactMap(map.node).map { (node.column, $0.column) }
            }
            for a in edges {
                for b in edges {
                    #expect(!(a.0 < b.0 && a.1 > b.1))
                }
            }
        }
    }

    @Test func standardRulesScaleAndReward() throws {
        let rules = StandardRunRules()
        var rng = SeededRandom(seed: 3)
        #expect(rules.enemyHP(base: 1_000, row: 5, kind: .combat) == 1_600)

        let early = rules.encounter(row: 0, kind: .combat, catalog: .standard, rng: &rng)
        #expect((1...2).contains(early.enemies.count))
        let late = rules.encounter(row: 8, kind: .combat, catalog: .standard, rng: &rng)
        #expect((2...3).contains(late.enemies.count))
        #expect(rules.encounter(row: 12, kind: .boss, catalog: .standard, rng: &rng).enemies.count == 1)

        let state = RunEngine(seed: 3, characterID: "kael").state
        let elite = rules.rewards(after: .elite, state: state, catalog: .standard, rng: &rng)
        #expect(elite.count == 3)
        for case let .relic(id) in elite {
            #expect(try #require(GameCatalog.standard.relic(id: id)).rarity >= .rare)
        }
    }
}
