import Foundation
import Observation
import PADRoguelikeCore

struct GameSettings {
    var moveDuration: TimeInterval = 5
    var hapticsEnabled = true
}

/// Options and the run in progress, saved in `UserDefaults` after every run action.
@MainActor
@Observable
final class GameProgress {
    private enum Key {
        static let moveDuration = "moveDuration"
        static let hapticsEnabled = "hapticsEnabled"
        static let runState = "runState"
    }

    var settings: GameSettings {
        didSet {
            defaults.set(settings.moveDuration, forKey: Key.moveDuration)
            defaults.set(settings.hapticsEnabled, forKey: Key.hapticsEnabled)
        }
    }

    /// Copy of `run.state`, refreshed after every action so SwiftUI redraws (the engine itself is not observable).
    private(set) var runState: RunState?
    @ObservationIgnored private(set) var run: RunEngine?
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let defaultSettings = GameSettings()
        settings = GameSettings(
            moveDuration: defaults.object(forKey: Key.moveDuration) as? Double ?? defaultSettings.moveDuration,
            hapticsEnabled: defaults.object(forKey: Key.hapticsEnabled) as? Bool ?? defaultSettings.hapticsEnabled
        )
        // A save from an older version or with an unknown character is dropped.
        if let data = defaults.data(forKey: Key.runState),
           let state = try? JSONDecoder().decode(RunState.self, from: data),
           GameCatalog.standard.character(id: state.characterID) != nil {
            run = RunEngine(restoring: state)
            runState = state
        }
    }

    // MARK: - Run

    func startRun(characterID: String) {
        run = RunEngine(seed: UInt64.random(in: .min ... .max), characterID: characterID)
        sync()
    }

    func chooseNode(_ index: Int) {
        try? run?.chooseNode(index)
        sync()
    }

    /// A fresh battle for the current encounter; leaving it and coming back restarts the fight.
    func makeBattle() -> BattleEngine? {
        try? run?.makeBattle()
    }

    func finishBattle(_ battle: BattleEngine) {
        try? run?.finishBattle(battle)
        sync()
    }

    /// `nil` skips the reward.
    func chooseReward(_ index: Int?) {
        try? run?.chooseReward(index)
        sync()
    }

    func endRun() {
        run = nil
        sync()
    }

    private func sync() {
        runState = run?.state
        if let runState, let data = try? JSONEncoder().encode(runState) {
            defaults.set(data, forKey: Key.runState)
        } else {
            defaults.removeObject(forKey: Key.runState)
        }
    }
}
