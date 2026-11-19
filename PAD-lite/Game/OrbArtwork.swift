import PADRoguelikeCore
import SpriteKit
import UIKit

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

    /// Highlight tone used by hero portraits.
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

extension OrbType {
    /// Name used for assets: `orb-fire`, `orb-water`, ...
    var assetKey: String {
        switch self {
        case .fire: "fire"
        case .water: "water"
        case .wood: "wood"
        case .light: "light"
        case .dark: "dark"
        case .heal: "heal"
        }
    }

    /// Placeholder icon (SF Symbol) drawn on the classic sphere.
    var symbolName: String {
        switch self {
        case .fire: "flame.fill"
        case .water: "drop.fill"
        case .wood: "leaf.fill"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        case .heal: "heart.fill"
        }
    }
}

/// Orbs. Add a square PNG (transparent background) named `orb-<type>` to `Assets.xcassets` to replace the
/// whole orb, or `orb-icon-<type>` to keep the classic sphere with your own icon on it.
enum OrbArtwork {
    static func texture(for type: OrbType, diameter: CGFloat, scale: CGFloat) -> SKTexture {
        SKTexture(image: image(for: type, diameter: diameter, scale: scale))
    }

    static func image(for type: OrbType, diameter: CGFloat, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let rect = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        return UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
            if let asset = UIImage(named: "orb-\(type.assetKey)") {
                asset.draw(in: rect)
                return
            }
            drawSphere(type, in: rect, context.cgContext)
            let iconRect = rect.insetBy(dx: rect.width * 0.3, dy: rect.height * 0.3)
            if let icon = UIImage(named: "orb-icon-\(type.assetKey)") {
                icon.draw(in: iconRect)
            } else {
                IconDrawing.drawSymbol(type.symbolName, in: iconRect, color: UIColor.white.withAlphaComponent(0.92))
            }
        }
    }

    private static func drawSphere(_ type: OrbType, in rect: CGRect, _ cg: CGContext) {
        let r = rect.width * 0.43
        let body = CGRect(x: rect.midX - r, y: rect.midY - r, width: 2 * r, height: 2 * r)
        cg.setFillColor(type.baseColor.cgColor)
        cg.fillEllipse(in: body)
        cg.setStrokeColor(type.rimColor.cgColor)
        cg.setLineWidth(max(1.5, r * 0.09))
        cg.strokeEllipse(in: body)
        cg.setFillColor(UIColor.white.withAlphaComponent(0.22).cgColor)
        cg.fillEllipse(in: CGRect(x: rect.midX - r * 0.7, y: rect.midY - r * 0.725, width: r * 1.1, height: r * 0.55))
    }
}
