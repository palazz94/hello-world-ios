import PADRoguelikeCore
import SwiftUI

enum Theme {
    static let background = LinearGradient(colors: [Color(red: 0.16, green: 0.08, blue: 0.26),
                                                    Color(red: 0.07, green: 0.04, blue: 0.13),
                                                    Color(red: 0.02, green: 0.02, blue: 0.06)],
                                           startPoint: .top, endPoint: .bottom)
    static let panel = Color(red: 0.11, green: 0.08, blue: 0.18)
    static let gold = Color(red: 1, green: 0.8, blue: 0.3)
    static let accent = Color(red: 0.55, green: 0.35, blue: 1)
    static let drawback = Color(red: 1, green: 0.45, blue: 0.45)
    static let bonus = Color(red: 0.6, green: 1, blue: 0.7)
}

extension Element {
    var color: Color { Color(uiColor: orbType.baseColor) }
}

extension CharacterDefinition {
    var symbol: String {
        switch id {
        case "kael": "flame.fill"
        case "nerea": "drop.fill"
        case "sylas": "leaf.fill"
        case "lumen": "sun.max.fill"
        case "umbra": "moon.fill"
        case "mira": "sparkles"
        default: "person.fill"
        }
    }
}

extension Relic {
    var symbol: String {
        switch id {
        case "four-leaf-lens": "square.grid.2x2.fill"
        case "giant-hammer": "hammer.fill"
        case "metronome": "metronome.fill"
        case "cracked-prism": "rhombus.fill"
        case "red-vial": "drop.fill"
        case "turtle-scale": "shield.lefthalf.filled"
        case "hourglass": "hourglass"
        case "twin-pearls": "circle.grid.2x1.fill"
        case "deep-root": "leaf.fill"
        case "loaded-coin": "dollarsign.circle.fill"
        case "bloody-blade": "bolt.fill"
        case "berserker-mask": "theatermasks.fill"
        case "balance-crown": "scalemass.fill"
        case "blood-contract": "signature"
        case "glass-heart": "heart.fill"
        case "chain": "link"
        case "rainbow-eye": "eye.fill"
        case "broken-hourglass": "hourglass.bottomhalf.filled"
        case "thorn-armor": "shield.fill"
        case "seal-of-four": "seal.fill"
        case "chaos-crown": "crown.fill"
        case "dark-pact": "moon.fill"
        case "phoenix-heart": "flame.fill"
        case "singularity": "circle.hexagongrid.fill"
        default: "sparkles"
        }
    }
}

// MARK: - Portraits and icons

struct HeroPortrait: View {
    let character: CharacterDefinition
    var size: CGFloat = 64

    var body: some View {
        let palette = character.element.orbType
        ZStack {
            Circle().fill(RadialGradient(colors: [Color(uiColor: palette.lightColor), Color(uiColor: palette.baseColor),
                                                  Color(uiColor: palette.rimColor)],
                                         center: .topLeading, startRadius: 0, endRadius: size * 1.1))
            Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.85), Color(uiColor: palette.rimColor)],
                                                 startPoint: .top, endPoint: .bottom),
                                  lineWidth: size * 0.06)
            Image(systemName: character.symbol)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: Color(uiColor: palette.rimColor), radius: 2)
        }
        .frame(width: size, height: size)
        .shadow(color: character.element.color.opacity(0.6), radius: size * 0.15)
    }
}

struct RelicIcon: View {
    let relic: Relic
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25)
                .fill(LinearGradient(colors: [relic.rarity.color.opacity(0.55), Color(red: 0.08, green: 0.05, blue: 0.14)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: size * 0.25).strokeBorder(relic.rarity.color, lineWidth: 2)
            Image(systemName: relic.symbol)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

struct OrbImage: View {
    let type: OrbType
    var size: CGFloat = 40
    @Environment(\.displayScale) private var scale

    var body: some View {
        Image(uiImage: OrbArtwork.image(for: type, diameter: size, scale: scale))
    }
}

struct EnemyPortrait: View {
    let name: String
    let element: Element
    var size: CGFloat = 64
    @Environment(\.displayScale) private var scale

    var body: some View {
        Image(uiImage: EnemyArtwork.image(name: name, element: element, side: size, scale: scale))
    }
}

struct GoldLabel: View {
    let amount: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle.fill")
                .font(.caption)
                .foregroundStyle(Theme.gold.gradient)
            Text("\(amount)")
                .font(.subheadline.bold())
                .monospacedDigit()
                .foregroundStyle(Theme.gold)
        }
    }
}

struct HPBarView: View {
    let current: Int
    let maximum: Int

    var body: some View {
        let fraction = maximum > 0 ? CGFloat(current) / CGFloat(maximum) : 0
        ZStack(alignment: .leading) {
            Capsule().fill(Color.black.opacity(0.5))
            GeometryReader { geometry in
                Capsule()
                    .fill(LinearGradient(colors: fraction > 0.3 ? [.green, Color(red: 0.2, green: 0.7, blue: 0.4)]
                                                                : [.red, .orange],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geometry.size.width * fraction)
            }
            Text("\(current) / \(maximum)")
                .font(.caption2.bold())
                .monospacedDigit()
                .frame(maxWidth: .infinity)
        }
        .frame(height: 16)
        .overlay(Capsule().strokeBorder(.white.opacity(0.25)))
    }
}

/// Effects list where drawbacks stand out in red.
struct ModifierList: View {
    let modifiers: [Modifier]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(modifiers.enumerated()), id: \.offset) { _, modifier in
                Label {
                    Text(modifier.displayText)
                } icon: {
                    Image(systemName: modifier.isDrawback ? "exclamationmark.triangle.fill" : "plus.circle.fill")
                }
                .font(.caption)
                .foregroundStyle(modifier.isDrawback ? Theme.drawback : Theme.bonus)
            }
        }
    }
}

struct RelicCard: View {
    let relic: Relic

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RelicIcon(relic: relic, size: 50)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(relic.name).font(.headline)
                    Spacer()
                    Text(relic.rarity.title.uppercased())
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(relic.rarity.color)
                }
                ModifierList(modifiers: relic.modifiers)
                if !relic.flavor.isEmpty {
                    Text(relic.flavor).font(.caption2.italic()).foregroundStyle(.secondary)
                }
            }
        }
        .cardStyle(border: relic.rarity.color)
    }
}

// MARK: - Containers and buttons

extension View {
    func cardStyle(border: Color = .white.opacity(0.15)) -> some View {
        padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(border.opacity(0.6), lineWidth: 1.5))
    }
}

/// Modal card shown over the map for every room.
struct PanelCard<Content: View>: View {
    let title: String
    let symbol: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(color.gradient).frame(width: 58, height: 58)
                Image(systemName: symbol).font(.title2.bold()).foregroundStyle(.white)
            }
            .shadow(color: color, radius: 12)
            Text(title).font(.title2.weight(.heavy))
            content
        }
        .padding(20)
        .frame(maxWidth: 520)
        .background(RoundedRectangle(cornerRadius: 28).fill(Theme.panel))
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(color.opacity(0.7), lineWidth: 2))
        .shadow(color: color.opacity(0.35), radius: 24)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.accent

    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonBody(configuration: configuration, color: color)
    }

    private struct PrimaryButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let color: Color
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(color.gradient))
                .overlay(Capsule().strokeBorder(.white.opacity(0.25)))
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .opacity(isEnabled ? 1 : 0.4)
        }
    }
}

/// Tappable card for choices (rewards, event options, rest).
struct ChoiceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ChoiceBody(configuration: configuration)
    }

    private struct ChoiceBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .frame(maxWidth: .infinity, alignment: .leading)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .brightness(configuration.isPressed ? 0.08 : 0)
                .opacity(isEnabled ? 1 : 0.4)
        }
    }
}
