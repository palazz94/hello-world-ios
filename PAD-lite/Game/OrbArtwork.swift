import PADRoguelikeCore
import SpriteKit
import UIKit

// MARK: - Placeholder artwork

extension OrbType {
    var baseColor: UIColor {
        switch self {
        case .fire: UIColor(red: 0.93, green: 0.26, blue: 0.21, alpha: 1)
        case .water: UIColor(red: 0.20, green: 0.52, blue: 0.96, alpha: 1)
        case .wood: UIColor(red: 0.24, green: 0.75, blue: 0.33, alpha: 1)
        case .light: UIColor(red: 0.98, green: 0.82, blue: 0.20, alpha: 1)
        case .dark: UIColor(red: 0.58, green: 0.30, blue: 0.84, alpha: 1)
        case .heal: UIColor(red: 0.97, green: 0.50, blue: 0.74, alpha: 1)
        }
    }

    var rimColor: UIColor {
        switch self {
        case .fire: UIColor(red: 0.55, green: 0.10, blue: 0.08, alpha: 1)
        case .water: UIColor(red: 0.08, green: 0.25, blue: 0.58, alpha: 1)
        case .wood: UIColor(red: 0.08, green: 0.40, blue: 0.15, alpha: 1)
        case .light: UIColor(red: 0.65, green: 0.48, blue: 0.05, alpha: 1)
        case .dark: UIColor(red: 0.30, green: 0.12, blue: 0.48, alpha: 1)
        case .heal: UIColor(red: 0.62, green: 0.20, blue: 0.42, alpha: 1)
        }
    }
}

/// Draws an orb as vector shapes; `GameScene` rasterizes the result into one texture per type.
enum OrbArtwork {
    static func node(for type: OrbType, radius r: CGFloat) -> SKNode {
        let root = SKNode()

        let body = SKShapeNode(circleOfRadius: r)
        body.fillColor = type.baseColor
        body.strokeColor = type.rimColor
        body.lineWidth = max(1.5, r * 0.09)
        root.addChild(body)

        let gloss = SKShapeNode(ellipseOf: CGSize(width: r * 1.1, height: r * 0.55))
        gloss.position = CGPoint(x: -r * 0.15, y: r * 0.45)
        gloss.fillColor = UIColor.white.withAlphaComponent(0.22)
        gloss.strokeColor = .clear
        root.addChild(gloss)

        root.addChild(symbol(for: type, radius: r))
        return root
    }

    private static func symbol(for type: OrbType, radius r: CGFloat) -> SKNode {
        let symbolColor = UIColor.white.withAlphaComponent(0.92)

        if type == .dark {
            let ring = SKShapeNode(circleOfRadius: r * 0.36)
            ring.fillColor = .clear
            ring.strokeColor = symbolColor
            ring.lineWidth = r * 0.13
            let dot = SKShapeNode(circleOfRadius: r * 0.13)
            dot.fillColor = symbolColor
            dot.strokeColor = .clear
            ring.addChild(dot)
            return ring
        }

        let shape = SKShapeNode(path: path(for: type, radius: r))
        shape.fillColor = symbolColor
        shape.strokeColor = type.rimColor
        shape.lineWidth = max(1, r * 0.05)
        shape.lineJoin = .round
        return shape
    }

    private static func path(for type: OrbType, radius r: CGFloat) -> CGPath {
        let p = CGMutablePath()
        switch type {
        case .fire:
            p.move(to: CGPoint(x: 0, y: 0.55 * r))
            p.addQuadCurve(to: CGPoint(x: 0.35 * r, y: -0.2 * r), control: CGPoint(x: 0.45 * r, y: 0.1 * r))
            p.addQuadCurve(to: CGPoint(x: -0.35 * r, y: -0.2 * r), control: CGPoint(x: 0, y: -0.7 * r))
            p.addQuadCurve(to: CGPoint(x: 0, y: 0.55 * r), control: CGPoint(x: -0.45 * r, y: 0.1 * r))
        case .water:
            p.move(to: CGPoint(x: 0, y: 0.55 * r))
            p.addQuadCurve(to: CGPoint(x: 0.36 * r, y: -0.15 * r), control: CGPoint(x: 0.36 * r, y: 0.15 * r))
            p.addArc(center: CGPoint(x: 0, y: -0.15 * r), radius: 0.36 * r,
                     startAngle: 0, endAngle: .pi, clockwise: true)
            p.addQuadCurve(to: CGPoint(x: 0, y: 0.55 * r), control: CGPoint(x: -0.36 * r, y: 0.15 * r))
        case .wood:
            p.move(to: CGPoint(x: -0.42 * r, y: -0.42 * r))
            p.addQuadCurve(to: CGPoint(x: 0.42 * r, y: 0.42 * r), control: CGPoint(x: -0.5 * r, y: 0.5 * r))
            p.addQuadCurve(to: CGPoint(x: -0.42 * r, y: -0.42 * r), control: CGPoint(x: 0.5 * r, y: -0.5 * r))
        case .light:
            for i in 0..<10 {
                let angle = CGFloat.pi / 2 + CGFloat(i) * .pi / 5
                let radius = (i.isMultiple(of: 2) ? 0.55 : 0.23) * r
                let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
                i == 0 ? p.move(to: point) : p.addLine(to: point)
            }
        case .heal:
            p.move(to: CGPoint(x: 0, y: -0.48 * r))
            p.addCurve(to: CGPoint(x: -0.5 * r, y: 0.12 * r),
                       control1: CGPoint(x: -0.25 * r, y: -0.25 * r),
                       control2: CGPoint(x: -0.5 * r, y: -0.1 * r))
            p.addArc(center: CGPoint(x: -0.25 * r, y: 0.12 * r), radius: 0.25 * r,
                     startAngle: .pi, endAngle: 0, clockwise: true)
            p.addArc(center: CGPoint(x: 0.25 * r, y: 0.12 * r), radius: 0.25 * r,
                     startAngle: .pi, endAngle: 0, clockwise: true)
            p.addCurve(to: CGPoint(x: 0, y: -0.48 * r),
                       control1: CGPoint(x: 0.5 * r, y: -0.1 * r),
                       control2: CGPoint(x: 0.25 * r, y: -0.25 * r))
        case .dark:
            break
        }
        p.closeSubpath()
        return p
    }
}
