import Foundation

/// Permanent upgrades bought with points earned by clearing levels.
public enum Talent: String, CaseIterable, Sendable {
    case vitality, power, recovery

    public static let maxRank = 3

    /// Bonus per rank as a fraction of the base stat.
    public var bonusPerRank: Double {
        switch self {
        case .vitality: 0.10
        case .power: 0.10
        case .recovery: 0.20
        }
    }
}

public extension Player {
    /// Returns a full-HP copy of `self` with talent bonuses applied; ranks are clamped to `0...Talent.maxRank`.
    func applying(talents ranks: [Talent: Int]) -> Player {
        func factor(_ talent: Talent) -> Double {
            1 + talent.bonusPerRank * Double(min(max(ranks[talent] ?? 0, 0), Talent.maxRank))
        }
        func scaled(_ value: Int, _ talent: Talent) -> Int {
            Int((Double(value) * factor(talent)).rounded())
        }
        return Player(maxHP: scaled(maxHP, .vitality),
                      attack: attack.mapValues { scaled($0, .power) },
                      recovery: scaled(recovery, .recovery))
    }
}
