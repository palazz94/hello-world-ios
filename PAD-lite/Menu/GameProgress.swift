import Foundation
import Observation
import PADRoguelikeCore

struct GameSettings {
    var moveDuration: TimeInterval = 5
    var hapticsEnabled = true
}

/// Unlocked levels, talents and options, saved in `UserDefaults`.
@MainActor
@Observable
final class GameProgress {
    private enum Key {
        static let completedLevels = "completedLevels"
        static let talentRanks = "talentRanks"
        static let moveDuration = "moveDuration"
        static let hapticsEnabled = "hapticsEnabled"
    }

    private(set) var completedLevels: Set<Int>
    private(set) var talentRanks: [Talent: Int]
    var settings: GameSettings {
        didSet {
            defaults.set(settings.moveDuration, forKey: Key.moveDuration)
            defaults.set(settings.hapticsEnabled, forKey: Key.hapticsEnabled)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        completedLevels = Set(defaults.array(forKey: Key.completedLevels) as? [Int] ?? [])
        let storedRanks = defaults.dictionary(forKey: Key.talentRanks) as? [String: Int] ?? [:]
        talentRanks = Dictionary(uniqueKeysWithValues: storedRanks.compactMap { key, rank in
            Talent(rawValue: key).map { ($0, rank) }
        })
        let defaultSettings = GameSettings()
        settings = GameSettings(
            moveDuration: defaults.object(forKey: Key.moveDuration) as? Double ?? defaultSettings.moveDuration,
            hapticsEnabled: defaults.object(forKey: Key.hapticsEnabled) as? Bool ?? defaultSettings.hapticsEnabled
        )
    }

    // MARK: - Levels

    /// The first level is always open; every other one needs the previous level cleared.
    func isUnlocked(_ level: Level) -> Bool {
        guard let index = Level.campaign.firstIndex(where: { $0.id == level.id }) else { return false }
        return index == 0 || completedLevels.contains(Level.campaign[index - 1].id)
    }

    func record(_ outcome: BattleOutcome, for level: Level) {
        guard outcome == .victory, completedLevels.insert(level.id).inserted else { return }
        defaults.set(Array(completedLevels), forKey: Key.completedLevels)
    }

    // MARK: - Talents

    /// One point per cleared level.
    var availableTalentPoints: Int {
        completedLevels.count - talentRanks.values.reduce(0, +)
    }

    func rank(of talent: Talent) -> Int { talentRanks[talent] ?? 0 }

    func canUpgrade(_ talent: Talent) -> Bool {
        availableTalentPoints > 0 && rank(of: talent) < Talent.maxRank
    }

    func upgrade(_ talent: Talent) {
        guard canUpgrade(talent) else { return }
        talentRanks[talent] = rank(of: talent) + 1
        saveTalents()
    }

    func resetTalents() {
        talentRanks.removeAll()
        saveTalents()
    }

    var player: Player { Player.test.applying(talents: talentRanks) }

    private func saveTalents() {
        defaults.set(Dictionary(uniqueKeysWithValues: talentRanks.map { ($0.key.rawValue, $0.value) }),
                     forKey: Key.talentRanks)
    }
}
