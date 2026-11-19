import PADRoguelikeCore
import SpriteKit
import UIKit

/// Battle scene: the board from `GameScene` at the bottom; enemies, ability buttons and the player HP bar on top.
/// Turn loop: (optional abilities) -> move orbs -> combos -> player attacks/heals -> enemy countdowns/attacks -> victory/defeat check.
@MainActor
final class TestBattleScene: GameScene {

    private enum Timing {
        static let playerHit: TimeInterval = 0.18
        static let heal: TimeInterval = 0.3
        static let beforeEnemyPhase: TimeInterval = 0.25
        static let enemyHit: TimeInterval = 0.4
    }

    private let battle: BattleEngine

    private let enemyLayer = SKNode()
    private var backdrop: SKSpriteNode?
    private var enemyNodes: [EnemyNode] = []
    private let abilityLayer = SKNode()
    private var abilityNodes: [AbilityButtonNode] = []
    private var playerBar: HPBarNode?
    private let turnLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var outcomeOverlay: SKNode?
    private var canRestart = false
    /// Called when the result screen is tapped; when nil the battle restarts instead.
    var onBattleEnd: ((BattleOutcome) -> Void)?

    private let targetFeedback = UISelectionFeedbackGenerator()
    private let damageFeedback = UIImpactFeedbackGenerator(style: .heavy)
    private let outcomeFeedback = UINotificationFeedbackGenerator()

    init(board: BoardEngine, battle: BattleEngine) {
        self.battle = battle
        super.init(engine: board)

        enemyLayer.zPosition = 300
        addChild(enemyLayer)

        abilityLayer.zPosition = 300
        addChild(abilityLayer)

        turnLabel.fontColor = UIColor.white.withAlphaComponent(0.7)
        turnLabel.horizontalAlignmentMode = .left
        turnLabel.verticalAlignmentMode = .top
        turnLabel.zPosition = 300
        addChild(turnLabel)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - Layout

    override func boardLayoutDidChange(_ layout: BoardLayout, boardFrame: CGRect, hudTop: CGFloat) {
        backdrop?.removeFromParent()
        let background = SKSpriteNode(texture: BackdropArtwork.texture(size: size, scale: view?.contentScaleFactor ?? 3),
                                      size: size)
        background.anchorPoint = .zero
        background.zPosition = -100
        addChild(background)
        backdrop = background

        let top = size.height - layout.topInset - 8
        let area = CGRect(x: boardFrame.minX, y: hudTop, width: boardFrame.width, height: max(0, top - hudTop))

        turnLabel.fontSize = max(13, layout.cellSize * 0.28)
        turnLabel.position = CGPoint(x: area.minX, y: area.maxY)

        playerBar?.removeFromParent()
        let barHeight = max(14, layout.cellSize * 0.3)
        let bar = HPBarNode(size: CGSize(width: area.width, height: barHeight),
                            color: UIColor(red: 0.30, green: 0.85, blue: 0.45, alpha: 1))
        bar.position = CGPoint(x: area.midX, y: area.minY + barHeight / 2)
        bar.zPosition = 300
        addChild(bar)
        playerBar = bar

        let abilityHeight = max(36, layout.cellSize * 0.7)
        let abilityGap: CGFloat = 8
        let abilityCount = CGFloat(battle.abilities.count)
        let abilityWidth = abilityCount > 0 ? (area.width - abilityGap * (abilityCount - 1)) / abilityCount : 0
        let abilityY = bar.position.y + barHeight / 2 + 8 + abilityHeight / 2
        abilityLayer.removeAllChildren()
        abilityNodes = battle.abilities.enumerated().map { index, ability in
            let node = AbilityButtonNode(title: ability.ability.name, size: CGSize(width: abilityWidth, height: abilityHeight))
            node.position = CGPoint(x: area.minX + abilityWidth / 2 + CGFloat(index) * (abilityWidth + abilityGap),
                                    y: abilityY)
            abilityLayer.addChild(node)
            return node
        }

        let enemiesBottom = (abilityNodes.isEmpty ? bar.position.y + barHeight / 2 : abilityY + abilityHeight / 2) + 12
        let enemiesTop = area.maxY - turnLabel.fontSize * 1.5
        let enemiesHeight = max(0, enemiesTop - enemiesBottom)
        let slotWidth = area.width / CGFloat(battle.enemies.count)
        let radius = max(12, min(slotWidth * 0.3, enemiesHeight * 0.24))

        enemyLayer.removeAllChildren()
        enemyNodes = battle.enemies.enumerated().map { index, enemy in
            let node = EnemyNode(enemy: enemy, radius: radius, width: slotWidth)
            // Extra content (HP bar, countdown) sits below the body, so the body is shifted up.
            node.position = CGPoint(x: area.minX + slotWidth * (CGFloat(index) + 0.5),
                                    y: enemiesBottom + enemiesHeight / 2 + radius * 0.35)
            enemyLayer.addChild(node)
            return node
        }
        refresh(animated: false)
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        if outcomeOverlay != nil {
            guard canRestart else { return }
            if let onBattleEnd {
                canRestart = false
                onBattleEnd(battle.outcome)
            } else {
                restartBattle()
            }
            return
        }

        let point = touch.location(in: enemyLayer)
        if let index = enemyNodes.firstIndex(where: { $0.contains(pointInParent: point) }) {
            if state == .idle, !isInputLocked, battle.selectTarget(index) {
                if hapticsEnabled { targetFeedback.selectionChanged() }
                refresh(animated: true)
            }
            return
        }

        let abilityPoint = touch.location(in: abilityLayer)
        if let index = abilityNodes.firstIndex(where: { $0.contains(pointInParent: abilityPoint) }) {
            if state == .idle, !isInputLocked { useAbility(index) }
            return
        }
        super.touchesBegan(touches, with: event)
    }

    // MARK: - Abilities

    private func useAbility(_ index: Int) {
        let report: AbilityReport
        do {
            report = try battle.useAbility(index, board: engine)
        } catch {
            return
        }
        isInputLocked = true
        if hapticsEnabled { targetFeedback.selectionChanged() }
        Task { [weak self] in
            await self?.playAbility(report)
        }
    }

    private func playAbility(_ report: AbilityReport) async {
        if report.boardRefreshed || !report.conversions.isEmpty { reloadOrbs() }
        for attack in report.attacks {
            show(attack)
            await wait(Timing.playerHit)
        }
        if report.healed > 0 {
            showPlayerChange(+report.healed)
            await wait(Timing.heal)
        }
        refresh(animated: true)

        switch report.outcome {
        case .ongoing: isInputLocked = false
        case .victory, .defeat: showOutcome(report.outcome)
        }
    }

    // MARK: - Turn loop

    override func boardDidFinishTurn(_ clusters: [MatchCluster]) {
        isInputLocked = true
        let report = battle.resolveTurn(clusters: clusters)
        Task { [weak self] in
            await self?.play(report)
        }
    }

    private func play(_ report: TurnReport) async {
        for attack in report.playerAttacks {
            show(attack)
            await wait(Timing.playerHit)
        }

        if report.healed > 0 {
            showPlayerChange(+report.healed)
            await wait(Timing.heal)
        }

        if report.selfDamage > 0 {
            showPlayerChange(-report.selfDamage)
            await wait(Timing.heal)
        }

        refresh(animated: true)

        if !report.enemyAttacks.isEmpty {
            await wait(Timing.beforeEnemyPhase)
            for hit in report.enemyAttacks {
                enemyNodes[safe: hit.enemyIndex]?.playAttack()
                if hit.damage > 0 {
                    showPlayerChange(-hit.damage)
                } else if let playerBar {
                    FloatingText.spawn("SCUDO", color: UIColor(red: 0.6, green: 0.85, blue: 1, alpha: 1),
                                       fontSize: max(18, playerBar.calculateAccumulatedFrame().height * 1.2),
                                       at: playerBar.position, in: self)
                }
                if hapticsEnabled { damageFeedback.impactOccurred() }
                await wait(Timing.enemyHit)
            }
        }

        refresh(animated: true)

        switch report.outcome {
        case .ongoing: isInputLocked = false
        case .victory, .defeat: showOutcome(report.outcome)
        }
    }

    private func show(_ attack: PlayerAttack) {
        guard let node = enemyNodes[safe: attack.targetIndex] else { return }
        switch attack.block {
        case .absorbed: node.showAbsorb(healed: attack.damage)
        case .comboShield: node.showImmune()
        case nil: node.showHit(damage: attack.damage, color: attack.element.orbType.baseColor)
        }
    }

    private func refresh(animated: Bool) {
        let active = Set(battle.activeEnemyIndices)
        let target = battle.targetIndex
        for (index, node) in enemyNodes.enumerated() {
            node.update(with: battle.enemies[index], isActive: active.contains(index),
                        isTarget: index == target, animated: animated)
        }
        playerBar?.set(current: battle.player.currentHP, maximum: battle.player.maxHP, animated: animated)
        for (index, node) in abilityNodes.enumerated() where battle.abilities.indices.contains(index) {
            node.update(with: battle.abilities[index])
        }
        turnLabel.text = "Turno \(battle.turn + 1)" + (battle.shield > 0 ? " · Scudo \(battle.shield)" : "")
    }

    private func showPlayerChange(_ delta: Int) {
        guard let playerBar else { return }
        playerBar.set(current: playerBar.current + delta, maximum: playerBar.maximum, animated: true)

        let isHeal = delta > 0
        FloatingText.spawn(isHeal ? "+\(delta)" : "\(delta)",
                           color: isHeal ? UIColor(red: 0.5, green: 1, blue: 0.6, alpha: 1)
                                         : UIColor(red: 1, green: 0.35, blue: 0.3, alpha: 1),
                           fontSize: max(18, playerBar.calculateAccumulatedFrame().height * 1.4),
                           at: playerBar.position, in: self)
        if !isHeal {
            playerBar.run(.sequence([
                .moveBy(x: 6, y: 0, duration: 0.03), .moveBy(x: -12, y: 0, duration: 0.06),
                .moveBy(x: 6, y: 0, duration: 0.03),
            ]))
        }
    }

    // MARK: - Victory / defeat

    private func showOutcome(_ outcome: BattleOutcome) {
        let isVictory = outcome == .victory
        if hapticsEnabled { outcomeFeedback.notificationOccurred(isVictory ? .success : .error) }

        let overlay = SKNode()
        overlay.zPosition = 1_000
        overlay.alpha = 0

        let dim = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.7), size: size)
        dim.anchorPoint = .zero
        overlay.addChild(dim)

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let title = SKLabelNode(fontNamed: "AvenirNext-HeavyItalic")
        title.text = isVictory ? "VITTORIA!" : "SCONFITTA"
        title.fontSize = min(size.width * 0.13, 56)
        title.fontColor = isVictory ? UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
                                    : UIColor(red: 1, green: 0.35, blue: 0.3, alpha: 1)
        title.position = center
        overlay.addChild(title)

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        subtitle.text = "Turni: \(battle.turn) - Tocca per \(onBattleEnd == nil ? "ricominciare" : "continuare")"
        subtitle.fontSize = 18
        subtitle.fontColor = .white
        subtitle.position = CGPoint(x: center.x, y: center.y - title.fontSize)
        overlay.addChild(subtitle)

        addChild(overlay)
        outcomeOverlay = overlay
        canRestart = false
        overlay.run(.sequence([.fadeIn(withDuration: 0.3), .wait(forDuration: 0.4)])) { [weak self] in
            self?.canRestart = true
        }
    }

    private func restartBattle() {
        outcomeOverlay?.removeFromParent()
        outcomeOverlay = nil
        canRestart = false
        battle.reset()
        resetBoard()
        refresh(animated: false)
        isInputLocked = false
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
