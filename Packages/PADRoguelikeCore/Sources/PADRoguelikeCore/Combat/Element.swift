import Foundation

public enum Element: String, CaseIterable, Sendable {
    case fire, water, wood, light, dark

    /// Damage multiplier when `self` attacks `defender`: fire > wood > water > fire, light <-> dark.
    public func multiplier(against defender: Element) -> Double {
        switch (self, defender) {
        case (.fire, .wood), (.wood, .water), (.water, .fire), (.light, .dark), (.dark, .light):
            2.0
        case (.wood, .fire), (.water, .wood), (.fire, .water):
            0.5
        default:
            1.0
        }
    }

    public var orbType: OrbType {
        switch self {
        case .fire: .fire
        case .water: .water
        case .wood: .wood
        case .light: .light
        case .dark: .dark
        }
    }
}

public extension OrbType {
    /// `nil` for `heal`, which recovers HP instead of attacking.
    var element: Element? {
        switch self {
        case .fire: .fire
        case .water: .water
        case .wood: .wood
        case .light: .light
        case .dark: .dark
        case .heal: nil
        }
    }
}
