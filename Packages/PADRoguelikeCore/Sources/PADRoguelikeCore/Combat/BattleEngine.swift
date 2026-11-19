import Foundation

public enum EncounterMode: Codable, Sendable {
    /// All enemies are on the field, act and can be targeted.
    case simultaneous
    /// Only the first alive enemy is active; the next one steps in when it falls.
    case sequential
}

public enum BattleOutcome: Sendable {
    case ongoing, victory, defeat
}

/// Defines the rules for calculating combat bonuses based on combos and orb clusters.
public struct CombatRules: Sendable {
    public var bonusPerExtraCombo: Double
    public var bonusPerExtraOrb: Double

    public init(bonusPerExtraCombo: Double = 0.25, bonusPerExtraOrb: Double = 0.25) {
        self.bonusPerExtraCombo = bonusPerExtraCombo
        self.bonusPerExtraOrb = bonusPerExtraOrb
    }

    /// 1 combo = x1, each extra combo adds `bonusPerExtraCombo`.
    public func comboMultiplier(comboCount: Int) -> Double {
        1 + bonusPerExtraCombo * Double(max(comboCount, 1) - 1)
    }

    /// 3 orbs = x1, each extra orb in the cluster adds `bonusPerExtraOrb`.
    public func orbMultiplier(orbCount: Int) -> Double {
        1 + bonusPerExtraOrb * Double(max(orbCount, 3) - 3)
    }
}

/// Represents a single attack made by the player during a turn.
public struct PlayerAttack: Sendable {
    public let element: Element
    public let targetIndex: Int
    /// Raw damage before clamping to the enemy's remaining HP; HP healed when `block == .absorbed`.
    public let damage: Int
    public let defeatedTarget: Bool
    public let block: HitBlock?
}

public struct EnemyAttack: Sendable {
    public let enemyIndex: Int
    /// HP actually removed from the player.
    public let damage: Int
    /// Damage absorbed by the shield.
    public let blocked: Int
}

public struct TurnReport: Sendable {
    public let turn: Int
    public let comboCount: Int
    public let playerAttacks: [PlayerAttack]
    public let healed: Int
    public let shieldGained: Int
    /// HP lost to own relics/talents (never lethal).
    public let selfDamage: Int
    public let enemyAttacks: [EnemyAttack]
    public let outcome: BattleOutcome
    /// Every modifier that changed a value this turn, in application order.
    public let appliedModifiers: [AppliedModifier]
}

/// Pure turn-based combat rules: turn-start triggers -> player attack/heal -> combo triggers -> enemy countdown/attack.
public final class BattleEngine {
    public let mode: EncounterMode
    public let rules: CombatRules
    /// Sources active for the whole battle (relics, passive talents).
    public let modifiers: [ModifierSource]

    public private(set) var player: Player
    public private(set) var enemies: [Enemy]
    public private(set) var turn = 0
    /// Absorbs enemy damage before HP; lasts until used up or the battle ends.
    public private(set) var shield = 0
    public private(set) var buffs: [TimedBuff] = []
    public private(set) var abilities: [AbilityState]
    private var preferredTarget: Int?

    private let initialPlayer: Player
    private let initialEnemies: [Enemy]
    private let initialAbilities: [AbilityState]

    public init(player: Player, enemies: [Enemy], mode: EncounterMode = .simultaneous, rules: CombatRules = CombatRules(),
                modifiers: [ModifierSource] = [], abilities: [AbilityState] = []) {
        precondition(!enemies.isEmpty, "A battle needs at least one enemy")
        self.player = player
        self.enemies = enemies
        self.mode = mode
        self.rules = rules
        self.modifiers = modifiers
        self.abilities = abilities
        self.initialPlayer = player
        self.initialEnemies = enemies
        self.initialAbilities = abilities
    }

    /// Permanent modifiers plus active buffs.
    public var resolver: ModifierResolver {
        ModifierResolver(rules: rules, sources: modifiers + buffs.map(\.source))
    }

    public var outcome: BattleOutcome {
        if player.isDefeated { return .defeat }
        if enemies.allSatisfy(\.isDefeated) { return .victory }
        return .ongoing
    }

    /// Enemies that can be targeted and whose countdown advances.
    public var activeEnemyIndices: [Int] {
        let alive = enemies.indices.filter { !enemies[$0].isDefeated }
        switch mode {
        case .simultaneous: return alive
        case .sequential: return Array(alive.prefix(1))
        }
    }

    /// The enemy that receives the next attack; falls back to the first active enemy.
    public var targetIndex: Int? {
        if let preferredTarget, activeEnemyIndices.contains(preferredTarget) { return preferredTarget }
        return activeEnemyIndices.first
    }

    @discardableResult
    public func selectTarget(_ index: Int) -> Bool {
        guard activeEnemyIndices.contains(index) else { return false }
        preferredTarget = index
        return true
    }

    /// Applies one player move. `clusters` are all combos of the move, cascades included.
    public func resolveTurn(clusters: [MatchCluster]) -> TurnReport {
        guard outcome == .ongoing else {
            return TurnReport(turn: turn, comboCount: 0, playerAttacks: [], healed: 0, shieldGained: 0, selfDamage: 0,
                              enemyAttacks: [], outcome: outcome, appliedModifiers: [])
        }
        turn += 1
        let resolver = self.resolver
        let activeAtStart = Set(activeEnemyIndices)
        let context = TurnContext(clusters: clusters, hpFraction: Double(player.currentHP) / Double(player.maxHP))
        var applied: [AppliedModifier] = []
        var healed = 0
        var shieldGained = 0
        var selfDamage = 0

        let startShield = resolver.turnStartShield()
        let startHeal = resolver.turnStartHeal()
        let startLoss = resolver.turnStartHPLoss()
        applied += startShield.applied + startHeal.applied + startLoss.applied
        shieldGained += startShield.value
        healed += player.heal(startHeal.value)
        selfDamage += player.drain(startLoss.value)

        var attacks: [PlayerAttack] = []
        for cluster in clusters {
            if let element = cluster.type.element {
                guard let target = targetIndex else { continue }
                let hit = resolver.damage(attack: player.attack[element] ?? 0, element: element, cluster: cluster,
                                          turn: context, defender: enemies[target].element)
                applied += hit.applied
                let result = enemies[target].receiveHit(hit.value, element: element, comboCount: clusters.count)
                attacks.append(PlayerAttack(element: element, targetIndex: target, damage: result.amount,
                                            defeatedTarget: enemies[target].isDefeated, block: result.block))
            } else {
                let heal = resolver.heal(recovery: player.recovery, cluster: cluster, turn: context)
                applied += heal.applied
                healed += player.heal(heal.value)
            }
        }

        let moveShield = resolver.moveShield(context)
        let moveHeal = resolver.moveHeal(context)
        let moveLoss = resolver.moveSelfDamage(context)
        applied += moveShield.applied + moveHeal.applied + moveLoss.applied
        shieldGained += moveShield.value
        healed += player.heal(moveHeal.value)
        selfDamage += player.drain(moveLoss.value)
        shield += shieldGained

        for index in enemies.indices { _ = enemies[index].regenerate() }

        var enemyAttacks: [EnemyAttack] = []
        // Enemies that entered the field during this turn wait until the next one.
        for index in activeEnemyIndices where activeAtStart.contains(index) {
            guard outcome == .ongoing else { break }
            guard enemies[index].advanceTurn() else { continue }
            let incoming = resolver.incomingDamage(enemies[index].currentAttack)
            enemies[index].didAttack()
            applied += incoming.applied
            let blocked = min(shield, incoming.value)
            shield -= blocked
            enemyAttacks.append(EnemyAttack(enemyIndex: index, damage: player.takeDamage(incoming.value - blocked),
                                            blocked: blocked))
        }

        buffs = buffs.compactMap { $0.ticked() }
        for index in abilities.indices { abilities[index].tick() }

        return TurnReport(turn: turn, comboCount: clusters.count, playerAttacks: attacks, healed: healed,
                          shieldGained: shieldGained, selfDamage: selfDamage, enemyAttacks: enemyAttacks,
                          outcome: outcome, appliedModifiers: applied)
    }

    /// Uses an ability before the next move. `board` is required only for board effects.
    public func useAbility(_ index: Int, board: BoardEngine? = nil) throws(AbilityError) -> AbilityReport {
        guard abilities.indices.contains(index) else { throw .invalidIndex }
        guard outcome == .ongoing else { throw .battleOver }
        let state = abilities[index]
        guard state.cooldownRemaining == 0 else { throw .onCooldown }
        guard state.chargesLeft != 0 else { throw .noCharges }
        guard player.currentHP > state.ability.hpCost else { throw .notEnoughHP }
        guard board != nil || !state.ability.needsBoard else { throw .needsBoard }

        _ = player.takeDamage(state.ability.hpCost)
        abilities[index].consume()
        var report = AbilityReport(abilityIndex: index)

        for effect in state.ability.effects {
            switch effect {
            case let .damage(target, element, multiplier):
                let targets = target == .allEnemies ? activeEnemyIndices : targetIndex.map { [$0] } ?? []
                for target in targets {
                    let raw = Double(player.attack[element] ?? 0) * multiplier
                        * element.multiplier(against: enemies[target].element)
                    let damage = Int(raw.rounded())
                    let result = enemies[target].receiveHit(damage, element: element, comboCount: nil)
                    report.attacks.append(PlayerAttack(element: element, targetIndex: target, damage: result.amount,
                                                       defeatedTarget: enemies[target].isDefeated, block: result.block))
                }
            case let .healPercent(fraction):
                report.healed += player.heal(Int((Double(player.maxHP) * fraction).rounded()))
            case let .shield(amount):
                shield += amount
                report.shieldGained += amount
            case let .delayEnemies(turns):
                for target in activeEnemyIndices { enemies[target].delay(by: turns) }
                report.delayedEnemies = activeEnemyIndices
            case let .buff(source, turns):
                if turns > 0 { buffs.append(TimedBuff(source: source, remainingTurns: turns)) }
            case let .convertOrbs(from, to):
                report.conversions += board?.convertOrbs(from: from, to: to) ?? []
            case .refreshBoard:
                board?.generateBoard()
                report.boardRefreshed = true
            }
        }
        report.outcome = outcome
        return report
    }

    public func reset() {
        player = initialPlayer
        enemies = initialEnemies
        abilities = initialAbilities
        turn = 0
        shield = 0
        buffs = []
        preferredTarget = nil
    }
}
