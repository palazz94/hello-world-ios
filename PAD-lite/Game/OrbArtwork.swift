import PADRoguelikeCore
import SpriteKit
import UIKit

extension OrbType {
    var baseColor: UIColor {
        switch self {
        case .fire: UIColor(red: 0.95, green: 0.25, blue: 0.2, alpha: 1)
        case .water: UIColor(red: 0.18, green: 0.55, blue: 1, alpha: 1)
        case .wood: UIColor(red: 0.2, green: 0.8, blue: 0.35, alpha: 1)
        case .light: UIColor(red: 1, green: 0.82, blue: 0.2, alpha: 1)
        case .dark: UIColor(red: 0.62, green: 0.3, blue: 0.9, alpha: 1)
        case .heal: UIColor(red: 1, green: 0.45, blue: 0.7, alpha: 1)
        }
    }

    var rimColor: UIColor {
        switch self {
        case .fire: UIColor(red: 0.45, green: 0.05, blue: 0.05, alpha: 1)
        case .water: UIColor(red: 0.04, green: 0.18, blue: 0.5, alpha: 1)
        case .wood: UIColor(red: 0.03, green: 0.32, blue: 0.12, alpha: 1)
        case .light: UIColor(red: 0.6, green: 0.38, blue: 0.02, alpha: 1)
        case .dark: UIColor(red: 0.22, green: 0.06, blue: 0.4, alpha: 1)
        case .heal: UIColor(red: 0.55, green: 0.1, blue: 0.3, alpha: 1)
        }
    }

    var lightColor: UIColor {
        switch self {
        case .fire: UIColor(red: 1, green: 0.72, blue: 0.45, alpha: 1)
        case .water: UIColor(red: 0.6, green: 0.88, blue: 1, alpha: 1)
        case .wood: UIColor(red: 0.7, green: 1, blue: 0.55, alpha: 1)
        case .light: UIColor(red: 1, green: 0.98, blue: 0.75, alpha: 1)
        case .dark: UIColor(red: 0.85, green: 0.65, blue: 1, alpha: 1)
        case .heal: UIColor(red: 1, green: 0.8, blue: 0.9, alpha: 1)
        }
    }
}

/// Orbs drawn as cut gems, each type with its own silhouette so colors are never the only cue.
enum OrbArtwork {
    static func texture(for type: OrbType, diameter: CGFloat, scale: CGFloat) -> SKTexture {
        SKTexture(image: image(for: type, diameter: diameter, scale: scale))
    }

    static func image(for type: OrbType, diameter: CGFloat, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let rect = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        return UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
            draw(type, in: rect, context.cgContext)
        }
    }

    // MARK: - Drawing

    private struct Polygon {
        let sides: Int
        let rotation: CGFloat
        let xScale: CGFloat
    }

    private static func polygon(for type: OrbType) -> Polygon? {
        switch type {
        case .fire: Polygon(sides: 6, rotation: -.pi / 2, xScale: 1)
        case .light: Polygon(sides: 4, rotation: -.pi / 2, xScale: 0.82)
        case .dark: Polygon(sides: 8, rotation: .pi / 8, xScale: 1)
        default: nil
        }
    }

    private static func vertices(of polygon: Polygon) -> [CGPoint] {
        (0..<polygon.sides).map { index in
            let angle = polygon.rotation + CGFloat(index) * 2 * .pi / CGFloat(polygon.sides)
            return CGPoint(x: cos(angle) * polygon.xScale, y: sin(angle))
        }
    }

    /// Unit-radius silhouette centred on the origin, y pointing down.
    private static func outline(for type: OrbType) -> CGPath {
        if let polygon = polygon(for: type) {
            let path = CGMutablePath()
            path.addLines(between: vertices(of: polygon))
            path.closeSubpath()
            return path
        }
        let path = CGMutablePath()
        switch type {
        case .water:
            path.move(to: CGPoint(x: 0, y: -1))
            path.addCurve(to: CGPoint(x: 0.8, y: 0.2), control1: CGPoint(x: 0.3, y: -0.55), control2: CGPoint(x: 0.8, y: -0.2))
            path.addArc(center: CGPoint(x: 0, y: 0.2), radius: 0.8, startAngle: 0, endAngle: .pi, clockwise: false)
            path.addCurve(to: CGPoint(x: 0, y: -1), control1: CGPoint(x: -0.8, y: -0.2), control2: CGPoint(x: -0.3, y: -0.55))
        case .wood:
            path.move(to: CGPoint(x: 0, y: -1))
            path.addQuadCurve(to: CGPoint(x: 0, y: 1), control: CGPoint(x: 1.25, y: 0))
            path.addQuadCurve(to: CGPoint(x: 0, y: -1), control: CGPoint(x: -1.25, y: 0))
            var rotation = CGAffineTransform(rotationAngle: .pi / 4)
            return path.copy(using: &rotation) ?? path
        case .heal:
            path.move(to: CGPoint(x: 0, y: 0.92))
            path.addCurve(to: CGPoint(x: -0.95, y: -0.25), control1: CGPoint(x: -0.55, y: 0.55), control2: CGPoint(x: -0.95, y: 0.15))
            path.addArc(center: CGPoint(x: -0.47, y: -0.3), radius: 0.48, startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
            path.addArc(center: CGPoint(x: 0.47, y: -0.3), radius: 0.48, startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
            path.addCurve(to: CGPoint(x: 0, y: 0.92), control1: CGPoint(x: 0.95, y: 0.15), control2: CGPoint(x: 0.55, y: 0.55))
        default:
            path.addEllipse(in: CGRect(x: -1, y: -1, width: 2, height: 2))
        }
        path.closeSubpath()
        return path
    }

    private static func draw(_ type: OrbType, in rect: CGRect, _ cg: CGContext) {
        let radius = rect.width / 2 * 0.84
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let unit = outline(for: type)
        var toRect = CGAffineTransform(translationX: center.x, y: center.y).scaledBy(x: radius, y: radius)
        guard let shape = unit.copy(using: &toRect) else { return }

        // Soft colored glow behind the gem.
        cg.saveGState()
        cg.setShadow(offset: .zero, blur: radius * 0.3, color: type.baseColor.withAlphaComponent(0.9).cgColor)
        cg.addPath(shape)
        cg.setFillColor(type.baseColor.cgColor)
        cg.fillPath()
        cg.restoreGState()

        cg.saveGState()
        cg.addPath(shape)
        cg.clip()

        let colors = [type.lightColor.cgColor, type.baseColor.cgColor, type.rimColor.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.45, 1]) {
            cg.drawLinearGradient(gradient,
                                  start: CGPoint(x: center.x - radius * 0.6, y: center.y - radius),
                                  end: CGPoint(x: center.x + radius * 0.6, y: center.y + radius),
                                  options: [])
        }

        // Table facet and the cuts joining it to the outline.
        let facetScale: CGFloat = 0.52
        let facetCenter = CGPoint(x: center.x, y: center.y - radius * 0.05)
        var toFacet = CGAffineTransform(translationX: facetCenter.x, y: facetCenter.y)
            .scaledBy(x: radius * facetScale, y: radius * facetScale)
        let lineColor = UIColor.white.withAlphaComponent(0.28).cgColor
        cg.setLineWidth(max(1, radius * 0.035))
        if let polygon = polygon(for: type) {
            cg.setStrokeColor(lineColor)
            for vertex in vertices(of: polygon) {
                cg.move(to: CGPoint(x: center.x + vertex.x * radius, y: center.y + vertex.y * radius))
                cg.addLine(to: CGPoint(x: facetCenter.x + vertex.x * radius * facetScale,
                                       y: facetCenter.y + vertex.y * radius * facetScale))
            }
            cg.strokePath()
        }
        if let facet = unit.copy(using: &toFacet) {
            cg.addPath(facet)
            cg.setFillColor(UIColor.white.withAlphaComponent(0.18).cgColor)
            cg.fillPath()
            cg.addPath(facet)
            cg.setStrokeColor(lineColor)
            cg.strokePath()
        }

        // Glossy reflection.
        cg.setFillColor(UIColor.white.withAlphaComponent(0.38).cgColor)
        cg.fillEllipse(in: CGRect(x: center.x - radius * 0.58, y: center.y - radius * 0.82,
                                  width: radius * 0.62, height: radius * 0.34))
        cg.restoreGState()

        cg.addPath(shape)
        cg.setStrokeColor(type.rimColor.cgColor)
        cg.setLineWidth(max(1.5, radius * 0.08))
        cg.setLineJoin(.round)
        cg.strokePath()

        drawSparkle(at: CGPoint(x: center.x - radius * 0.32, y: center.y - radius * 0.55), size: radius * 0.2, cg)
    }

    private static func drawSparkle(at point: CGPoint, size: CGFloat, _ cg: CGContext) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: point.x, y: point.y - size))
        path.addQuadCurve(to: CGPoint(x: point.x + size, y: point.y), control: point)
        path.addQuadCurve(to: CGPoint(x: point.x, y: point.y + size), control: point)
        path.addQuadCurve(to: CGPoint(x: point.x - size, y: point.y), control: point)
        path.addQuadCurve(to: CGPoint(x: point.x, y: point.y - size), control: point)
        cg.addPath(path)
        cg.setFillColor(UIColor.white.withAlphaComponent(0.9).cgColor)
        cg.fillPath()
    }
}
