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

/// One enemy slot: body coloured by element, name, HP bar, attack countdown and target marker.
@MainActor
final class EnemyNode: SKNode {
    let radius: CGFloat
    private let body: SKShapeNode
    private let targetRing: SKShapeNode
    private let nameLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let elementLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let countdownLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let hpBar: HPBarNode

    init(enemy: Enemy, radius: CGFloat, width: CGFloat) {
        self.radius = radius
        let fontSize = max(10, radius * 0.3)
        let barHeight = max(10, fontSize * 1.1)

        body = SKShapeNode(circleOfRadius: radius)
        body.fillColor = enemy.element.orbType.baseColor
        body.strokeColor = enemy.element.orbType.rimColor
        body.lineWidth = max(2, radius * 0.08)

        targetRing = SKShapeNode(circleOfRadius: radius * 1.18)
        targetRing.fillColor = .clear
        targetRing.strokeColor = UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
        targetRing.lineWidth = 3
        targetRing.isHidden = true

        hpBar = HPBarNode(size: CGSize(width: width * 0.85, height: barHeight),
                          color: UIColor(red: 0.92, green: 0.25, blue: 0.25, alpha: 1))
        super.init()

        for label in [nameLabel, elementLabel, countdownLabel] {
            label.fontColor = .white
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.fontSize = fontSize
        }
        nameLabel.text = enemy.name
        nameLabel.position = CGPoint(x: 0, y: radius + fontSize * 0.9)
        elementLabel.text = enemy.element.displayName
        elementLabel.fontSize = radius * 0.32
        hpBar.position = CGPoint(x: 0, y: -radius - 8 - barHeight / 2)
        countdownLabel.position = CGPoint(x: 0, y: hpBar.position.y - barHeight / 2 - fontSize * 0.9)

        let pulse = SKAction.sequence([.fadeAlpha(to: 0.4, duration: 0.5), .fadeAlpha(to: 1, duration: 0.5)])
        targetRing.run(.repeatForever(pulse))

        addChild(targetRing)
        addChild(body)
        body.addChild(elementLabel)
        addChild(nameLabel)
        addChild(hpBar)
        addChild(countdownLabel)

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
            countdownLabel.text = "Attacco: \(enemy.turnCountdown)"
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
        FloatingText.spawn("-\(damage)", color: color, fontSize: radius * 0.5,
                           at: CGPoint(x: 0, y: radius * 0.3), in: self)
    }

    func playAttack() {
        body.run(.sequence([
            .group([.moveBy(x: 0, y: -radius * 0.3, duration: 0.08), .scale(to: 1.15, duration: 0.08)]),
            .group([.moveBy(x: 0, y: radius * 0.3, duration: 0.14), .scale(to: 1, duration: 0.14)]),
        ]))
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
