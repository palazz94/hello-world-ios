import Foundation

public enum EnemyTier: String, Codable, Sendable {
    case minion, elite, boss
}

/// Unscaled enemy; `RunRules` turns it into an `Enemy` for a given row. Content lives in `Resources/enemies.json`.
public struct EnemyTemplate: Hashable, Codable, Sendable {
    public let name: String
    public let element: Element
    public let tier: EnemyTier
    public let baseHP: Int
    public let baseAttack: Int
    public let turnInterval: Int
    public let traits: [EnemyTrait]
    /// First map row where it can appear.
    public let minRow: Int

    public init(name: String, element: Element, tier: EnemyTier, baseHP: Int, baseAttack: Int, turnInterval: Int,
                traits: [EnemyTrait] = [], minRow: Int = 0) {
        self.name = name
        self.element = element
        self.tier = tier
        self.baseHP = baseHP
        self.baseAttack = baseAttack
        self.turnInterval = turnInterval
        self.traits = traits
        self.minRow = minRow
    }
}

/// Everything a run can draw from. Saves store only ids, resolved against this at load time.
public struct GameCatalog: Sendable {
    public var relics: [Relic]
    public var characters: [CharacterDefinition]
    public var enemies: [EnemyTemplate]
    public var events: [RunEvent]

    public init(relics: [Relic], characters: [CharacterDefinition], enemies: [EnemyTemplate], events: [RunEvent]) {
        self.relics = relics
        self.characters = characters
        self.enemies = enemies
        self.events = events
    }

    public func relic(id: String) -> Relic? { relics.first { $0.id == id } }
    public func character(id: String) -> CharacterDefinition? { characters.first { $0.id == id } }
    public func event(id: String) -> RunEvent? { events.first { $0.id == id } }
}

// MARK: - Loading

public struct CatalogError: Error, CustomStringConvertible, Sendable {
    public let file: String
    public let message: String

    public var description: String { "\(file): \(message)" }
}

public extension GameCatalog {
    static let files = (heroes: "heroes", enemies: "enemies", relics: "relics", events: "events")

    /// The content shipped in the package. A broken file stops the app with a readable message;
    /// `swift test` reports the same problem first.
    static let standard: GameCatalog = {
        do {
            return try load()
        } catch {
            preconditionFailure("Invalid game data. \(error)")
        }
    }()

    /// Reads `heroes.json`, `enemies.json`, `relics.json` and `events.json` from `directory`
    /// (default: the package resources), then checks they are consistent.
    static func load(from directory: URL? = nil) throws -> GameCatalog {
        func read<T: Decodable>(_ name: String) throws -> T {
            let url = directory?.appendingPathComponent("\(name).json")
                ?? Bundle.module.url(forResource: name, withExtension: "json")
            guard let url, let data = try? Data(contentsOf: url) else {
                throw CatalogError(file: "\(name).json", message: "file not found")
            }
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch let error as DecodingError {
                throw CatalogError(file: "\(name).json", message: describe(error))
            }
        }

        let catalog = GameCatalog(relics: try read(files.relics), characters: try read(files.heroes),
                                  enemies: try read(files.enemies), events: try read(files.events))
        let problems = catalog.validate()
        guard problems.isEmpty else {
            throw CatalogError(file: "catalog", message: problems.joined(separator: "; "))
        }
        return catalog
    }

    /// Consistency problems the JSON schema cannot catch (duplicates, impossible values, missing tiers).
    func validate() -> [String] {
        var problems: [String] = []
        func duplicates(_ values: [String]) -> [String] {
            Dictionary(grouping: values, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
        }
        for id in duplicates(relics.map(\.id)) { problems.append("relic id \"\(id)\" is duplicated") }
        for id in duplicates(characters.map(\.id)) { problems.append("hero id \"\(id)\" is duplicated") }
        for id in duplicates(events.map(\.id)) { problems.append("event id \"\(id)\" is duplicated") }
        for name in duplicates(enemies.map(\.name)) { problems.append("enemy \"\(name)\" is duplicated") }

        if characters.isEmpty { problems.append("there are no heroes") }
        for hero in characters {
            if hero.baseHP <= 0 { problems.append("hero \(hero.id): baseHP must be positive") }
            for talent in hero.talents where !(1...CharacterDefinition.maxLevel).contains(talent.unlockLevel) {
                problems.append("hero \(hero.id): talent \(talent.id) unlockLevel must be 1...\(CharacterDefinition.maxLevel)")
            }
        }
        for tier in [EnemyTier.minion, .elite, .boss] where !enemies.contains(where: { $0.tier == tier }) {
            problems.append("there are no \(tier.rawValue) enemies")
        }
        if !enemies.contains(where: { $0.tier == .minion && $0.minRow == 0 }) {
            problems.append("no minion can appear on row 0 (minRow 0)")
        }
        for enemy in enemies where enemy.baseHP <= 0 || enemy.turnInterval <= 0 {
            problems.append("enemy \(enemy.name): baseHP and turnInterval must be positive")
        }
        for relic in relics where relic.modifiers.isEmpty {
            problems.append("relic \(relic.id) has no modifiers")
        }
        if events.isEmpty { problems.append("there are no events") }
        for event in events {
            if event.options.isEmpty { problems.append("event \(event.id) has no options") }
            for option in event.options {
                for case let .fight(kind) in option.effects where kind != .combat && kind != .elite {
                    problems.append("event \(event.id): fights can only be \"combat\" or \"elite\"")
                }
            }
        }
        return problems
    }
}

/// "relics.json → [3].modifiers[0].factor: value not found" instead of Foundation's raw dump.
private func describe(_ error: DecodingError) -> String {
    func path(_ context: DecodingError.Context) -> String {
        let parts = context.codingPath.map { key in key.intValue.map { "[\($0)]" } ?? ".\(key.stringValue)" }
        return parts.joined().trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
    switch error {
    case let .keyNotFound(key, context):
        return "\(path(context)): missing field \"\(key.stringValue)\""
    case let .typeMismatch(type, context):
        return "\(path(context)): expected \(type). \(context.debugDescription)"
    case let .valueNotFound(type, context):
        return "\(path(context)): missing \(type)"
    case let .dataCorrupted(context):
        return "\(path(context)): \(context.debugDescription)"
    @unknown default:
        return "\(error)"
    }
}
