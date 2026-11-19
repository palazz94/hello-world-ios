import PADRoguelikeCore
import SpriteKit
import UIKit

extension Element {
    var displayName: String {
        switch self {
        case .fire: "Fuoco"
        case .water: "Acqua"
        case .wood: "Legno"
        case .light: "Luce"
        case .dark: "Buio"
        }
    }
}

/// Horizontal HP bar centred on its position, with "current / max" text inside.
@MainActor
final class HPBarNode: SKNode {
    private let fill: SKSpriteNode
    private let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private(set) var current = 0
    private(set) var maximum = 1

    init(size: CGSize, color: UIColor) {
        fill = SKSpriteNode(color: color, size: size)
        super.init()

        let track = SKShapeNode(rect: CGRect(x: -size.width / 2, y: -size.height / 2,
                                             width: size.width, height: size.height),
                                cornerRadius: size.height / 2)
        track.fillColor = UIColor.black.withAlphaComponent(0.55)
        track.strokeColor = UIColor.white.withAlphaComponent(0.3)
        track.lineWidth = 1
        addChild(track)

        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.position = CGPoint(x: -size.width / 2, y: 0)
        fill.zPosition = 1
        addChild(fill)

        label.fontSize = size.height * 0.75
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 2
        addChild(label)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    func set(current: Int, maximum: Int, animated: Bool) {
        self.current = max(0, current)
        self.maximum = max(1, maximum)
        label.text = "\(self.current) / \(self.maximum)"

        let fraction = CGFloat(self.current) / CGFloat(self.maximum)
        fill.removeAction(forKey: "hp")
        if animated {
            let resize = SKAction.scaleX(to: fraction, duration: 0.25)
            resize.timingMode = .easeOut
            fill.run(resize, withKey: "hp")
        } else {
            fill.xScale = fraction
        }
    }
}

/// One enemy slot: illustrated portrait, name, HP bar, attack countdown, traits and target marker.
@MainActor
final class EnemyNode: SKNode {
    let radius: CGFloat
    private let body: SKSpriteNode
    private let targetRing: SKShapeNode
    private let nameLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let traitsLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let countdownLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let hpBar: HPBarNode

    init(enemy: Enemy, radius: CGFloat, width: CGFloat) {
        self.radius = radius
        let fontSize = max(10, radius * 0.3)
        let barHeight = max(10, fontSize * 1.1)

        let side = radius * 2.6
        body = SKSpriteNode(texture: EnemyArtwork.texture(name: enemy.name, element: enemy.element, side: side,
                                                          scale: UITraitCollection.current.displayScale),
                            size: CGSize(width: side, height: side))

        targetRing = SKShapeNode(ellipseOf: CGSize(width: radius * 2.3, height: radius * 0.7))
        targetRing.fillColor = UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 0.15)
        targetRing.strokeColor = UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
        targetRing.lineWidth = 3
        targetRing.position = CGPoint(x: 0, y: -radius * 0.95)
        targetRing.isHidden = true

        hpBar = HPBarNode(size: CGSize(width: width * 0.85, height: barHeight),
                          color: UIColor(red: 0.92, green: 0.25, blue: 0.25, alpha: 1))
        super.init()

        for label in [nameLabel, traitsLabel, countdownLabel] {
            label.fontColor = .white
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.fontSize = fontSize
        }
        nameLabel.text = enemy.name
        nameLabel.position = CGPoint(x: 0, y: radius * 1.25 + fontSize * 0.6)
        hpBar.position = CGPoint(x: 0, y: -radius * 1.25 - barHeight / 2)
        countdownLabel.position = CGPoint(x: 0, y: hpBar.position.y - barHeight / 2 - fontSize * 0.9)
        traitsLabel.text = enemy.traits.map(\.title).joined(separator: " · ")
        traitsLabel.fontSize = fontSize * 0.85
        traitsLabel.fontColor = UIColor(red: 1, green: 0.7, blue: 0.35, alpha: 1)
        traitsLabel.position = CGPoint(x: 0, y: countdownLabel.position.y - fontSize * 1.1)

        let pulse = SKAction.sequence([.fadeAlpha(to: 0.4, duration: 0.5), .fadeAlpha(to: 1, duration: 0.5)])
        targetRing.run(.repeatForever(pulse))
        let bob = SKAction.sequence([.moveBy(x: 0, y: radius * 0.06, duration: 0.9),
                                     .moveBy(x: 0, y: -radius * 0.06, duration: 0.9)])
        bob.timingMode = .easeInEaseOut
        body.run(.repeatForever(bob), withKey: "idle")

        addChild(targetRing)
        addChild(body)
        addChild(nameLabel)
        addChild(hpBar)
        addChild(countdownLabel)
        addChild(traitsLabel)

        update(with: enemy, isActive: true, isTarget: false, animated: false)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(with enemy: Enemy, isActive: Bool, isTarget: Bool, animated: Bool = true) {
        hpBar.set(current: enemy.currentHP, maximum: enemy.maxHP, animated: animated)
        targetRing.isHidden = !isTarget || enemy.isDefeated

        let targetAlpha: CGFloat
        if enemy.isDefeated {
            countdownLabel.text = "Sconfitto"
            countdownLabel.fontColor = .lightGray
            targetAlpha = 0.3
        } else if !isActive {
            countdownLabel.text = "In attesa"
            countdownLabel.fontColor = .lightGray
            targetAlpha = 0.5
        } else {
            countdownLabel.text = "Attacco: \(enemy.turnCountdown) · \(enemy.currentAttack)"
            countdownLabel.fontColor = enemy.turnCountdown <= 1
                ? UIColor(red: 1, green: 0.4, blue: 0.35, alpha: 1)
                : .white
            targetAlpha = 1
        }

        if animated {
            run(.fadeAlpha(to: targetAlpha, duration: 0.2))
        } else {
            alpha = targetAlpha
        }
    }

    func contains(pointInParent point: CGPoint) -> Bool {
        hypot(point.x - position.x, point.y - position.y) <= radius * 1.3
    }

    /// Applies the hit visually; the authoritative HP is set by the next `update(with:)`.
    func showHit(damage: Int, color: UIColor) {
        hpBar.set(current: hpBar.current - damage, maximum: hpBar.maximum, animated: true)
        body.run(.sequence([
            .moveBy(x: radius * 0.12, y: 0, duration: 0.03),
            .moveBy(x: -radius * 0.24, y: 0, duration: 0.06),
            .moveBy(x: radius * 0.12, y: 0, duration: 0.03),
        ]))
        body.run(.sequence([.colorize(with: .white, colorBlendFactor: 0.7, duration: 0.03),
                            .colorize(withColorBlendFactor: 0, duration: 0.15)]))
        FloatingText.spawn("-\(damage)", color: color, fontSize: radius * 0.5,
                           at: CGPoint(x: 0, y: radius * 0.3), in: self)
    }

    func showAbsorb(healed: Int) {
        hpBar.set(current: hpBar.current + healed, maximum: hpBar.maximum, animated: true)
        FloatingText.spawn("ASSORBE +\(healed)", color: UIColor(red: 0.5, green: 1, blue: 0.6, alpha: 1),
                           fontSize: radius * 0.38, at: CGPoint(x: 0, y: radius * 0.3), in: self)
    }

    func showImmune() {
        FloatingText.spawn("IMMUNE", color: UIColor(white: 0.85, alpha: 1), fontSize: radius * 0.4,
                           at: CGPoint(x: 0, y: radius * 0.3), in: self)
    }

    func playAttack() {
        body.run(.sequence([
            .group([.moveBy(x: 0, y: -radius * 0.3, duration: 0.08), .scale(to: 1.15, duration: 0.08)]),
            .group([.moveBy(x: 0, y: radius * 0.3, duration: 0.14), .scale(to: 1, duration: 0.14)]),
        ]))
    }
}

/// Ability button: name plus status (ready, cooldown, charges, HP cost).
@MainActor
final class AbilityButtonNode: SKNode {
    private let size: CGSize
    private let background: SKShapeNode
    private let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let statusLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")

    init(title: String, size: CGSize) {
        self.size = size
        background = SKShapeNode(rectOf: size, cornerRadius: min(10, size.height / 3))
        super.init()

        background.lineWidth = 2
        addChild(background)

        titleLabel.text = title
        titleLabel.fontSize = min(size.height * 0.32, 16)
        titleLabel.position = CGPoint(x: 0, y: size.height * 0.15)
        statusLabel.fontSize = min(size.height * 0.24, 12)
        statusLabel.position = CGPoint(x: 0, y: -size.height * 0.22)
        for label in [titleLabel, statusLabel] {
            label.fontColor = .white
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            addChild(label)
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(with state: AbilityState) {
        let gold = UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
        statusLabel.text = Self.status(of: state)
        background.fillColor = state.isReady ? gold.withAlphaComponent(0.25) : UIColor.white.withAlphaComponent(0.06)
        background.strokeColor = state.isReady ? gold : UIColor.white.withAlphaComponent(0.2)
        alpha = state.isReady ? 1 : 0.6
    }

    func contains(pointInParent point: CGPoint) -> Bool {
        abs(point.x - position.x) <= size.width / 2 && abs(point.y - position.y) <= size.height / 2
    }

    private static func status(of state: AbilityState) -> String {
        if state.chargesLeft == 0 { return "Esaurita" }
        if state.cooldownRemaining > 0 { return "Ricarica: \(state.cooldownRemaining)" }
        var parts = ["Pronta"]
        if let charges = state.chargesLeft { parts.append("\(charges)x") }
        if state.ability.hpCost > 0 { parts.append("-\(state.ability.hpCost) HP") }
        return parts.joined(separator: " · ")
    }
}

enum FloatingText {
    @MainActor
    static func spawn(_ text: String, color: UIColor, fontSize: CGFloat, at point: CGPoint, in parent: SKNode) {
        let label = SKLabelNode(fontNamed: "AvenirNext-HeavyItalic")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = color
        label.position = point
        label.zPosition = 50
        label.verticalAlignmentMode = .center
        parent.addChild(label)

        let rise = SKAction.moveBy(x: 0, y: fontSize * 1.6, duration: 0.7)
        rise.timingMode = .easeOut
        label.run(.sequence([
            .group([rise, .sequence([.wait(forDuration: 0.4), .fadeOut(withDuration: 0.3)])]),
            .removeFromParent(),
        ]))
    }
}
