import PADRoguelikeCore
import SpriteKit
import UIKit

/// Enemy portraits. Add a square PNG (transparent background) to `Assets.xcassets` named
/// `enemy-<name>` (lowercase, spaces → dashes, no accents, e.g. `enemy-fuoco-fatuo`) to replace the placeholder.
enum EnemyArtwork {
    /// Placeholder icons (SF Symbols) used when no asset exists.
    private static let symbols: [String: String] = [
        "Slime": "drop.fill",
        "Fuoco Fatuo": "flame.fill",
        "Granchio": "tortoise.fill",
        "Pipistrello": "bird.fill",
        "Fungo Velenoso": "leaf.fill",
        "Spiritello": "sparkles",
        "Scheletro": "figure.stand",
        "Golem di Fango": "cube.fill",
        "Mimic": "shippingbox.fill",
        "Salamandra": "lizard.fill",
        "Cavaliere Oscuro": "shield.fill",
        "Treant Antico": "tree.fill",
        "Drago Giovane": "flame.circle.fill",
        "Leviatano": "fish.fill",
        "Drago Rosso": "crown.fill",
        "Lich": "moon.stars.fill",
        "Titano": "mountain.2.fill",
    ]

    static func assetName(for name: String) -> String {
        "enemy-" + name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
    }

    static func image(name: String, element: Element, side: CGFloat, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let rect = CGRect(x: 0, y: 0, width: side, height: side)
        return UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
            if let asset = UIImage(named: assetName(for: name)) {
                asset.draw(in: rect)
                return
            }
            let disc = rect.insetBy(dx: side * 0.12, dy: side * 0.12)
            let cg = context.cgContext
            cg.setFillColor(element.orbType.baseColor.cgColor)
            cg.fillEllipse(in: disc)
            cg.setStrokeColor(element.orbType.rimColor.cgColor)
            cg.setLineWidth(max(2, side * 0.03))
            cg.strokeEllipse(in: disc)
            IconDrawing.drawSymbol(symbols[name] ?? "pawprint.fill", in: disc.insetBy(dx: disc.width * 0.22, dy: disc.height * 0.22))
        }
    }

    static func texture(name: String, element: Element, side: CGFloat, scale: CGFloat) -> SKTexture {
        SKTexture(image: image(name: name, element: element, side: side, scale: scale))
    }
}

/// Battle background. Add an asset named `battle-background` to replace the gradient.
enum BackdropArtwork {
    static func texture(size: CGSize, scale: CGFloat) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            if let asset = UIImage(named: "battle-background") {
                asset.draw(in: CGRect(origin: .zero, size: size))
                return
            }
            let colors = [UIColor(red: 0.2, green: 0.1, blue: 0.32, alpha: 1).cgColor,
                          UIColor(red: 0.09, green: 0.05, blue: 0.17, alpha: 1).cgColor,
                          UIColor(red: 0.03, green: 0.02, blue: 0.07, alpha: 1).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1]) {
                context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
        }
        return SKTexture(image: image)
    }
}

enum IconDrawing {
    /// Draws a white SF Symbol fitted inside `rect`, in the current UIKit context.
    static func drawSymbol(_ name: String, in rect: CGRect, color: UIColor = .white) {
        let configuration = UIImage.SymbolConfiguration(pointSize: rect.height, weight: .bold)
        guard let symbol = UIImage(systemName: name, withConfiguration: configuration)?
            .withTintColor(color, renderingMode: .alwaysOriginal) else { return }
        let fit = min(rect.width / symbol.size.width, rect.height / symbol.size.height)
        let size = CGSize(width: symbol.size.width * fit, height: symbol.size.height * fit)
        symbol.draw(in: CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2,
                               width: size.width, height: size.height))
    }
}
