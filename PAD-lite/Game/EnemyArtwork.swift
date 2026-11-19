import PADRoguelikeCore
import SpriteKit
import UIKit

/// Procedural monster portraits: each enemy name maps to a body plan, colors come from its element.
enum EnemyArtwork {
    enum Body: CaseIterable { case blob, round, spiky, block, tall }
    enum Mouth { case smile, teeth, none }
    enum Aura { case none, elite, boss }

    struct Look {
        var body: Body
        var eyes = 2
        var mouth = Mouth.smile
        var horns = false
        var wings = false
        var cap = false
        var crown = false
        var aura = Aura.none
    }

    static func look(for name: String) -> Look {
        switch name {
        case "Slime": Look(body: .blob)
        case "Fuoco Fatuo": Look(body: .round, mouth: .none, horns: true)
        case "Granchio": Look(body: .spiky, mouth: .teeth)
        case "Pipistrello": Look(body: .round, mouth: .teeth, wings: true)
        case "Fungo Velenoso": Look(body: .blob, cap: true)
        case "Spiritello": Look(body: .round, eyes: 1, wings: true)
        case "Scheletro": Look(body: .tall, mouth: .teeth)
        case "Golem di Fango": Look(body: .block, eyes: 1, mouth: .none)
        case "Mimic": Look(body: .block, eyes: 1, mouth: .teeth)
        case "Salamandra": Look(body: .spiky, mouth: .teeth, horns: true)
        case "Cavaliere Oscuro": Look(body: .tall, eyes: 1, mouth: .none, horns: true, aura: .elite)
        case "Treant Antico": Look(body: .tall, mouth: .teeth, horns: true, aura: .elite)
        case "Drago Giovane": Look(body: .spiky, mouth: .teeth, horns: true, wings: true, aura: .elite)
        case "Leviatano": Look(body: .round, eyes: 3, mouth: .teeth, aura: .elite)
        case "Drago Rosso": Look(body: .spiky, mouth: .teeth, horns: true, wings: true, crown: true, aura: .boss)
        case "Lich": Look(body: .tall, mouth: .none, wings: true, crown: true, aura: .boss)
        case "Titano": Look(body: .block, eyes: 3, mouth: .teeth, horns: true, crown: true, aura: .boss)
        default:
            let hash = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
            return Look(body: Body.allCases[hash % Body.allCases.count], eyes: 1 + hash % 3,
                        mouth: hash % 2 == 0 ? .teeth : .smile, horns: hash % 5 == 0)
        }
    }

    static func image(name: String, element: Element, side: CGFloat, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let rect = CGRect(x: 0, y: 0, width: side, height: side)
        return UIGraphicsImageRenderer(size: rect.size, format: format).image { context in
            draw(look(for: name), palette: element.orbType, in: rect, context.cgContext)
        }
    }

    static func texture(name: String, element: Element, side: CGFloat, scale: CGFloat) -> SKTexture {
        SKTexture(image: image(name: name, element: element, side: side, scale: scale))
    }

    // MARK: - Drawing

    private static func draw(_ look: Look, palette: OrbType, in rect: CGRect, _ cg: CGContext) {
        let u = rect.width * 0.3
        let c = CGPoint(x: rect.midX, y: rect.midY + u * 0.1)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: c.x + x * u, y: c.y + y * u) }
        let bone = UIColor(white: 0.95, alpha: 1)

        if look.aura != .none {
            let color = look.aura == .boss ? UIColor(red: 1, green: 0.2, blue: 0.2, alpha: 0.55)
                                           : UIColor(red: 1, green: 0.8, blue: 0.3, alpha: 0.45)
            let colors = [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                cg.drawRadialGradient(gradient, startCenter: c, startRadius: u * 0.5, endCenter: c, endRadius: u * 1.65,
                                      options: [])
            }
        }

        cg.setFillColor(UIColor.black.withAlphaComponent(0.35).cgColor)
        cg.fillEllipse(in: CGRect(x: c.x - u * 0.85, y: c.y + u * 0.92, width: u * 1.7, height: u * 0.32))

        if look.wings {
            for side: CGFloat in [-1, 1] {
                let wing = CGMutablePath()
                wing.move(to: p(side * 0.5, -0.25))
                wing.addQuadCurve(to: p(side * 1.55, -0.95), control: p(side * 1.0, -1.0))
                wing.addLine(to: p(side * 1.35, -0.35))
                wing.addLine(to: p(side * 1.6, -0.1))
                wing.addLine(to: p(side * 1.2, 0.15))
                wing.addLine(to: p(side * 1.3, 0.45))
                wing.addQuadCurve(to: p(side * 0.55, 0.4), control: p(side * 0.9, 0.2))
                wing.closeSubpath()
                fill(wing, with: palette.rimColor, stroke: UIColor.black.withAlphaComponent(0.5), width: u * 0.05, cg)
            }
        }

        if look.horns {
            for side: CGFloat in [-1, 1] {
                let horn = CGMutablePath()
                horn.move(to: p(side * 0.48, -0.62))
                horn.addQuadCurve(to: p(side * 0.85, -1.42), control: p(side * 0.95, -0.8))
                horn.addQuadCurve(to: p(side * 0.15, -0.8), control: p(side * 0.45, -1.05))
                horn.closeSubpath()
                fill(horn, with: bone, stroke: palette.rimColor, width: u * 0.05, cg)
            }
        }

        let body = bodyPath(look.body, center: c, unit: u)
        cg.saveGState()
        cg.addPath(body)
        cg.clip()
        let colors = [palette.lightColor.cgColor, palette.baseColor.cgColor, palette.rimColor.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1]) {
            cg.drawLinearGradient(gradient, start: p(-0.7, -1.1), end: p(0.7, 1.1), options: [])
        }
        cg.setFillColor(UIColor.white.withAlphaComponent(0.14).cgColor)
        cg.fillEllipse(in: CGRect(x: c.x - u * 0.45, y: c.y + u * 0.05, width: u * 0.9, height: u * 0.7))
        cg.setFillColor(UIColor.white.withAlphaComponent(0.3).cgColor)
        cg.fillEllipse(in: CGRect(x: c.x - u * 0.65, y: c.y - u * 0.8, width: u * 0.5, height: u * 0.28))
        cg.restoreGState()
        cg.addPath(body)
        cg.setStrokeColor(palette.rimColor.cgColor)
        cg.setLineWidth(u * 0.07)
        cg.setLineJoin(.round)
        cg.strokePath()

        if look.cap {
            let cap = CGMutablePath()
            cap.move(to: p(-1.2, -0.35))
            cap.addCurve(to: p(1.2, -0.35), control1: p(-1.15, -1.55), control2: p(1.15, -1.55))
            cap.addQuadCurve(to: p(-1.2, -0.35), control: p(0, -0.1))
            fill(cap, with: UIColor(red: 0.85, green: 0.2, blue: 0.3, alpha: 1), stroke: UIColor(red: 0.4, green: 0.05, blue: 0.1, alpha: 1),
                 width: u * 0.06, cg)
            cg.setFillColor(bone.cgColor)
            for (x, y, r) in [(-0.55, -0.75, 0.14), (0.1, -1.0, 0.18), (0.65, -0.65, 0.12)] {
                cg.fillEllipse(in: CGRect(x: c.x + (x - r) * u, y: c.y + (y - r) * u, width: 2 * r * u, height: 2 * r * u))
            }
        }

        let faceY: CGFloat = switch look.body {
        case .tall: -0.45
        case .blob: 0.05
        default: -0.1
        }
        let fierce = look.aura != .none || palette == .dark
        drawEyes(count: look.eyes, faceY: faceY, glowing: fierce, p: p, unit: u, cg)
        if look.aura != .none {
            cg.setStrokeColor(palette.rimColor.cgColor)
            cg.setLineWidth(u * 0.09)
            cg.setLineCap(.round)
            cg.move(to: p(-0.6, faceY - 0.42))
            cg.addLine(to: p(-0.15, faceY - 0.25))
            cg.move(to: p(0.6, faceY - 0.42))
            cg.addLine(to: p(0.15, faceY - 0.25))
            cg.strokePath()
        }
        drawMouth(look.mouth, y: faceY + 0.45, p: p, unit: u, cg)

        if look.crown {
            let top: CGFloat = look.body == .tall ? -1.02 : -0.92
            let crown = CGMutablePath()
            crown.move(to: p(-0.5, top + 0.05))
            crown.addLine(to: p(-0.55, top - 0.4))
            crown.addLine(to: p(-0.27, top - 0.18))
            crown.addLine(to: p(0, top - 0.5))
            crown.addLine(to: p(0.27, top - 0.18))
            crown.addLine(to: p(0.55, top - 0.4))
            crown.addLine(to: p(0.5, top + 0.05))
            crown.closeSubpath()
            fill(crown, with: UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 1), stroke: UIColor(red: 0.55, green: 0.35, blue: 0, alpha: 1),
                 width: u * 0.05, cg)
        }
    }

    private static func bodyPath(_ body: Body, center c: CGPoint, unit u: CGFloat) -> CGPath {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: c.x + x * u, y: c.y + y * u) }
        let path = CGMutablePath()
        switch body {
        case .blob:
            path.move(to: p(-1, 0.75))
            path.addCurve(to: p(0, -0.95), control1: p(-1.05, -0.2), control2: p(-0.6, -0.95))
            path.addCurve(to: p(1, 0.75), control1: p(0.6, -0.95), control2: p(1.05, -0.2))
            path.addQuadCurve(to: p(0.33, 0.8), control: p(0.66, 1.0))
            path.addQuadCurve(to: p(-0.33, 0.8), control: p(0, 0.95))
            path.addQuadCurve(to: p(-1, 0.75), control: p(-0.66, 1.0))
        case .round:
            path.addEllipse(in: CGRect(x: c.x - 0.9 * u, y: c.y - 0.9 * u, width: 1.8 * u, height: 1.8 * u))
        case .spiky:
            let points = 12
            path.addLines(between: (0..<(points * 2)).map { index in
                let angle = -CGFloat.pi / 2 + CGFloat(index) * .pi / CGFloat(points)
                let radius: CGFloat = index.isMultiple(of: 2) ? 1.0 : 0.78
                return p(cos(angle) * radius, sin(angle) * radius)
            })
        case .block:
            path.addRoundedRect(in: CGRect(x: c.x - 0.9 * u, y: c.y - 0.85 * u, width: 1.8 * u, height: 1.7 * u),
                                cornerWidth: 0.3 * u, cornerHeight: 0.3 * u)
        case .tall:
            path.addRoundedRect(in: CGRect(x: c.x - 0.62 * u, y: c.y - 1.0 * u, width: 1.24 * u, height: 2.0 * u),
                                cornerWidth: 0.55 * u, cornerHeight: 0.55 * u)
        }
        path.closeSubpath()
        return path
    }

    private static func drawEyes(count: Int, faceY: CGFloat, glowing: Bool, p: (CGFloat, CGFloat) -> CGPoint,
                                 unit u: CGFloat, _ cg: CGContext) {
        let layout: [(CGFloat, CGFloat, CGFloat)] = switch count {
        case 1: [(0, faceY, 0.3)]
        case 3: [(-0.42, faceY + 0.05, 0.17), (0, faceY - 0.22, 0.17), (0.42, faceY + 0.05, 0.17)]
        default: [(-0.33, faceY, 0.21), (0.33, faceY, 0.21)]
        }
        for (x, y, r) in layout {
            let center = p(x, y)
            let eye = CGRect(x: center.x - r * u, y: center.y - r * u * 1.1, width: 2 * r * u, height: 2.2 * r * u)
            if glowing {
                cg.saveGState()
                cg.setShadow(offset: .zero, blur: r * u, color: UIColor.yellow.cgColor)
                cg.setFillColor(UIColor(red: 1, green: 0.9, blue: 0.3, alpha: 1).cgColor)
                cg.fillEllipse(in: eye)
                cg.restoreGState()
                cg.setFillColor(UIColor.black.cgColor)
                cg.fillEllipse(in: CGRect(x: center.x - r * u * 0.18, y: center.y - r * u * 0.85, width: r * u * 0.36, height: r * u * 1.7))
            } else {
                cg.setFillColor(UIColor.white.cgColor)
                cg.fillEllipse(in: eye)
                cg.setFillColor(UIColor(white: 0.08, alpha: 1).cgColor)
                cg.fillEllipse(in: CGRect(x: center.x - r * u * 0.5, y: center.y - r * u * 0.3, width: r * u, height: r * u * 1.1))
                cg.setFillColor(UIColor.white.cgColor)
                cg.fillEllipse(in: CGRect(x: center.x - r * u * 0.1, y: center.y - r * u * 0.15, width: r * u * 0.3, height: r * u * 0.3))
            }
        }
    }

    private static func drawMouth(_ mouth: Mouth, y: CGFloat, p: (CGFloat, CGFloat) -> CGPoint, unit u: CGFloat,
                                  _ cg: CGContext) {
        switch mouth {
        case .none:
            return
        case .smile:
            cg.setStrokeColor(UIColor(white: 0.08, alpha: 1).cgColor)
            cg.setLineWidth(u * 0.08)
            cg.setLineCap(.round)
            cg.move(to: p(-0.28, y - 0.05))
            cg.addQuadCurve(to: p(0.28, y - 0.05), control: p(0, y + 0.2))
            cg.strokePath()
        case .teeth:
            let mouthRect = CGRect(x: p(-0.4, 0).x, y: p(0, y - 0.12).y, width: 0.8 * u, height: 0.3 * u)
            cg.setFillColor(UIColor(red: 0.2, green: 0.02, blue: 0.05, alpha: 1).cgColor)
            cg.addPath(CGPath(roundedRect: mouthRect, cornerWidth: 0.12 * u, cornerHeight: 0.12 * u, transform: nil))
            cg.fillPath()
            cg.setFillColor(UIColor.white.cgColor)
            let teeth = 4
            let width = mouthRect.width / CGFloat(teeth)
            for index in 0..<teeth {
                let x = mouthRect.minX + CGFloat(index) * width
                cg.move(to: CGPoint(x: x, y: mouthRect.minY))
                cg.addLine(to: CGPoint(x: x + width, y: mouthRect.minY))
                cg.addLine(to: CGPoint(x: x + width / 2, y: mouthRect.minY + mouthRect.height * 0.55))
                cg.closePath()
            }
            cg.fillPath()
        }
    }

    private static func fill(_ path: CGPath, with color: UIColor, stroke: UIColor, width: CGFloat, _ cg: CGContext) {
        cg.addPath(path)
        cg.setFillColor(color.cgColor)
        cg.fillPath()
        cg.addPath(path)
        cg.setStrokeColor(stroke.cgColor)
        cg.setLineWidth(width)
        cg.setLineJoin(.round)
        cg.strokePath()
    }
}

/// Battle background: night-sky gradient, stars and a hill silhouette behind the enemies.
enum BackdropArtwork {
    static func texture(size: CGSize, scale: CGFloat) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            let colors = [UIColor(red: 0.2, green: 0.1, blue: 0.32, alpha: 1).cgColor,
                          UIColor(red: 0.09, green: 0.05, blue: 0.17, alpha: 1).cgColor,
                          UIColor(red: 0.03, green: 0.02, blue: 0.07, alpha: 1).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1]) {
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }

            var seed: UInt64 = 0x5EED
            func next() -> CGFloat {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return CGFloat(seed >> 33) / CGFloat(UInt32.max >> 1)
            }
            for _ in 0..<90 {
                let point = CGPoint(x: next() * size.width, y: next() * size.height * 0.5)
                let radius = 0.5 + next() * 1.4
                cg.setFillColor(UIColor.white.withAlphaComponent(0.25 + next() * 0.6).cgColor)
                cg.fillEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
            }

            for (index, color) in [UIColor(red: 0.14, green: 0.08, blue: 0.24, alpha: 1),
                                   UIColor(red: 0.08, green: 0.05, blue: 0.14, alpha: 1)].enumerated() {
                let base = size.height * (0.4 + 0.06 * CGFloat(index))
                let hills = CGMutablePath()
                hills.move(to: CGPoint(x: 0, y: size.height))
                hills.addLine(to: CGPoint(x: 0, y: base))
                let steps = 6
                for step in 1...steps {
                    let x = size.width * CGFloat(step) / CGFloat(steps)
                    let peak = base - size.height * (0.03 + 0.04 * next())
                    hills.addQuadCurve(to: CGPoint(x: x, y: base), control: CGPoint(x: x - size.width / CGFloat(steps * 2), y: peak))
                }
                hills.addLine(to: CGPoint(x: size.width, y: size.height))
                hills.closeSubpath()
                cg.addPath(hills)
                cg.setFillColor(color.cgColor)
                cg.fillPath()
            }
        }
        return SKTexture(image: image)
    }
}
