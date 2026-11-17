import Testing
@testable import PADRoguelikeCore

private func cluster(_ type: OrbType, orbs: Int = 3) -> MatchCluster {
    MatchCluster(type: type, positions: (0..<orbs).map { GridPosition(col: $0, row: 0) })
}

private func makeBattle(_ mode: EncounterMode = .simultaneous) -> BattleEngine {
    BattleEngine(player: .test, enemies: Enemy.testRoster, mode: mode)
}

@Suite struct BattleEngineTests {

    @Test func elementAdvantageTable() {
        #expect(Element.fire.multiplier(against: .wood) == 2)
        #expect(Element.fire.multiplier(against: .water) == 0.5)
        #expect(Element.light.multiplier(against: .dark) == 2)
        #expect(Element.light.multiplier(against: .fire) == 1)
        #expect(OrbType.heal.element == nil)
    }

    @Test func advantageousHitDefeatsMinion() {
        let battle = makeBattle()
        let report = battle.resolveTurn(clusters: [cluster(.fire)])
        #expect(report.playerAttacks.first?.damage == 2_000)
        #expect(report.playerAttacks.first?.defeatedTarget == true)
        #expect(battle.enemies[0].currentHP == 0)
    }

    @Test func resistedHitDealsHalfDamage() {
        let battle = makeBattle()
        #expect(battle.selectTarget(1))
        _ = battle.resolveTurn(clusters: [cluster(.fire)])
        #expect(battle.enemies[1].currentHP == 6_000 - 500)
    }

    @Test func comboAndOrbMultipliersStack() {
        let battle = makeBattle()
        battle.selectTarget(2)
        let report = battle.resolveTurn(clusters: [cluster(.fire, orbs: 5), cluster(.water)])
        // fire: 1000 * 1.5 (5 orbs) * 1.25 (2 combo) * 1 ; water: 1000 * 1.25 * 2 (vs fire)
        #expect(report.playerAttacks.map(\.damage) == [1_875, 2_500])
    }

    @Test func healIsClampedToMaxHP() {
        let battle = makeBattle()
        _ = battle.resolveTurn(clusters: [])
        #expect(battle.player.currentHP == 4_700)
        let report = battle.resolveTurn(clusters: [cluster(.heal, orbs: 4)])
        #expect(report.healed == 300)
    }

    @Test func countdownsTriggerAttacksAndDefeat() {
        let battle = makeBattle()
        let damagePerTurn = (0..<4).map { _ in battle.resolveTurn(clusters: []).enemyAttacks.map(\.damage).reduce(0, +) }
        #expect(damagePerTurn == [300, 1_200, 2_800, 700])
        #expect(battle.outcome == .defeat)
        #expect(battle.resolveTurn(clusters: [cluster(.fire)]).playerAttacks.isEmpty)
    }

    @Test func sequentialModeRetargetsWithoutFreeAttack() {
        let battle = makeBattle(.sequential)
        #expect(battle.activeEnemyIndices == [0])
        #expect(!battle.selectTarget(2))

        let report = battle.resolveTurn(clusters: [cluster(.fire), cluster(.water)])
        #expect(report.playerAttacks.map(\.targetIndex) == [0, 1])
        #expect(report.enemyAttacks.isEmpty)
        #expect(battle.activeEnemyIndices == [1])
    }

    @Test func victoryAndReset() {
        let battle = BattleEngine(player: .test, enemies: [
            Enemy(id: 0, name: "A", element: .wood, maxHP: 100, attackPower: 1, turnInterval: 1),
            Enemy(id: 1, name: "B", element: .wood, maxHP: 100, attackPower: 1, turnInterval: 1),
        ])
        let report = battle.resolveTurn(clusters: [cluster(.fire), cluster(.fire)])
        #expect(report.outcome == .victory)
        #expect(report.enemyAttacks.isEmpty)

        battle.reset()
        #expect(battle.outcome == .ongoing)
        #expect(battle.turn == 0)
        #expect(battle.enemies.allSatisfy { $0.currentHP == $0.maxHP })
    }
}
