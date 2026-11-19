import Foundation

/// Hooks that shape a run. Implement this to change the map, difficulty curve, rooms or rewards
/// without touching `RunEngine`. All randomness must come from `rng` to keep runs reproducible.
public protocol RunRules: Sendable {
    var restHealFraction: Double { get }

    func makeMap(rng: inout SeededRandom) -> RunMap
    func encounter(row: Int, kind: NodeKind, catalog: GameCatalog, rng: inout SeededRandom) -> Encounter
    func enemyHP(base: Int, row: Int, kind: NodeKind) -> Int
    func enemyAttack(base: Int, row: Int, kind: NodeKind) -> Int
    /// Gold granted automatically after winning a fight.
    func gold(after kind: NodeKind, rng: inout SeededRandom) -> Int
    /// Choices offered after clearing a node; empty means no reward screen.
    func rewards(after kind: NodeKind, state: RunState, catalog: GameCatalog, rng: inout SeededRandom) -> [Reward]
    func shop(state: RunState, catalog: GameCatalog, rng: inout SeededRandom) -> [ShopItem]
    func event(state: RunState, catalog: GameCatalog, rng: inout SeededRandom) -> RunEvent
}

public struct StandardRunRules: RunRules {
    /// Regular rows; the boss sits alone on the row after them.
    public var rows = 12
    public var columns = 7
    public var paths = 6
    public var hpGrowthPerRow = 0.12
    public var attackGrowthPerRow = 0.06
    public var restHealFraction = 0.35

    public init() {}

    // MARK: - Map

    /// Paths climb one row at a time, moving at most one column sideways and never crossing.
    /// Row 0 is all fights, the middle row all treasure, the last row before the boss all rest sites.
    public func makeMap(rng: inout SeededRandom) -> RunMap {
        var used = Array(repeating: Array(repeating: false, count: columns), count: rows)
        var edges = Array(repeating: [(from: Int, to: Int)](), count: rows)
        var firstStart = -1

        for path in 0..<paths {
            var column = Int.random(in: 0..<columns, using: &rng)
            if path == 0 { firstStart = column }
            if path == 1, column == firstStart { column = (column + 1 + Int.random(in: 0..<(columns - 1), using: &rng)) % columns }

            for row in 0..<rows {
                used[row][column] = true
                guard row < rows - 1 else { break }
                let options = [column - 1, column, column + 1].filter { (0..<columns).contains($0) }.shuffled(using: &rng)
                let next = options.first { candidate in
                    !edges[row].contains { ($0.from < column && $0.to > candidate) || ($0.from > column && $0.to < candidate) }
                } ?? column
                if !edges[row].contains(where: { $0.from == column && $0.to == next }) {
                    edges[row].append((column, next))
                }
                column = next
            }
        }

        var ids = Array(repeating: Array(repeating: -1, count: columns), count: rows)
        var cells: [(row: Int, column: Int)] = []
        for row in 0..<rows {
            for column in 0..<columns where used[row][column] {
                ids[row][column] = cells.count
                cells.append((row, column))
            }
        }
        let bossID = cells.count

        var kinds = Array(repeating: Array(repeating: NodeKind.combat, count: columns), count: rows)
        for (row, column) in cells {
            let parents = row == 0 ? [] : edges[row - 1].filter { $0.to == column }.map { kinds[row - 1][$0.from] }
            kinds[row][column] = kind(row: row, parents: Set(parents), rng: &rng)
        }

        var nodes = cells.map { row, column in
            let next = row == rows - 1 ? [bossID]
                : edges[row].filter { $0.from == column }.map { ids[row + 1][$0.to] }.sorted()
            return MapNode(id: ids[row][column], row: row, column: column, kind: kinds[row][column], next: next)
        }
        nodes.append(MapNode(id: bossID, row: rows, column: columns / 2, kind: .boss, next: []))
        return RunMap(columns: columns, nodes: nodes)
    }

    private func kind(row: Int, parents: Set<NodeKind>, rng: inout SeededRandom) -> NodeKind {
        if row == 0 { return .combat }
        if row == rows / 2 { return .treasure }
        if row == rows - 1 { return .rest }
        // Special rooms never follow a room of the same kind.
        let options: [(NodeKind, Int)] = [
            (.combat, 45),
            (.event, 22),
            (.elite, row >= 4 ? 16 : 0),
            (.rest, row >= 4 && row != rows - 2 ? 12 : 0),
            (.shop, row >= 2 ? 7 : 0),
        ].filter { kind, weight in weight > 0 && (kind == .combat || kind == .event || !parents.contains(kind)) }
        return weightedPick(options, rng: &rng) ?? .combat
    }

    // MARK: - Fights

    public func encounter(row: Int, kind: NodeKind, catalog: GameCatalog, rng: inout SeededRandom) -> Encounter {
        let tier: EnemyTier = switch kind {
        case .boss: .boss
        case .elite: .elite
        default: .minion
        }
        let available = catalog.enemies.filter { $0.tier == tier && $0.minRow <= row }
        let pool = available.isEmpty ? catalog.enemies.filter { $0.tier == tier } : available
        precondition(!pool.isEmpty, "The catalog has no \(tier) enemies")

        let count = switch kind {
        case .combat: row < 3 ? Int.random(in: 1...2, using: &rng) : Int.random(in: 2...3, using: &rng)
        default: 1
        }
        let enemies = (0..<count).map { index in
            let template = pool[Int.random(in: pool.indices, using: &rng)]
            return Enemy(id: index, name: template.name, element: template.element,
                         maxHP: enemyHP(base: template.baseHP, row: row, kind: kind),
                         attackPower: enemyAttack(base: template.baseAttack, row: row, kind: kind),
                         turnInterval: template.turnInterval, traits: template.traits)
        }
        return Encounter(kind: kind, mode: .simultaneous, enemies: enemies)
    }

    public func enemyHP(base: Int, row: Int, kind: NodeKind) -> Int {
        max(1, Int((Double(base) * (1 + hpGrowthPerRow * Double(max(row, 0)))).rounded()))
    }

    public func enemyAttack(base: Int, row: Int, kind: NodeKind) -> Int {
        max(0, Int((Double(base) * (1 + attackGrowthPerRow * Double(max(row, 0)))).rounded()))
    }

    // MARK: - Rewards

    public func gold(after kind: NodeKind, rng: inout SeededRandom) -> Int {
        switch kind {
        case .combat: Int.random(in: 15...25, using: &rng)
        case .elite: Int.random(in: 35...50, using: &rng)
        default: 0
        }
    }

    /// Combat: a relic, a small heal or gold. Elite: two rare+ relics or a level. Treasure: three relics.
    public func rewards(after kind: NodeKind, state: RunState, catalog: GameCatalog, rng: inout SeededRandom) -> [Reward] {
        switch kind {
        case .combat:
            let relic = randomRelics(1, weights: [(.common, 75), (.rare, 25)], state: state, catalog: catalog, rng: &rng)
            return relic.map { .relic(id: $0.id) } + [.heal(0.2), .gold(35)]
        case .elite:
            let relics = randomRelics(2, weights: [(.rare, 80), (.legendary, 20)], state: state, catalog: catalog, rng: &rng)
            let level: Reward = state.characterLevel < CharacterDefinition.maxLevel ? .levelUp : .heal(0.3)
            return relics.map { .relic(id: $0.id) } + [level]
        case .treasure:
            return randomRelics(3, weights: [(.common, 50), (.rare, 35), (.legendary, 15)], state: state, catalog: catalog,
                                rng: &rng).map { .relic(id: $0.id) }
        default:
            return []
        }
    }

    public func shop(state: RunState, catalog: GameCatalog, rng: inout SeededRandom) -> [ShopItem] {
        let relics = randomRelics(3, weights: [(.common, 55), (.rare, 35), (.legendary, 10)], state: state, catalog: catalog,
                                  rng: &rng)
        var items = relics.map { relic in
            let base = switch relic.rarity {
            case .common: 70
            case .rare: 120
            case .legendary: 180
            }
            return ShopItem(reward: .relic(id: relic.id), price: base + Int.random(in: 0...15, using: &rng))
        }
        items.append(ShopItem(reward: .heal(0.3), price: 50))
        if state.characterLevel < CharacterDefinition.maxLevel {
            items.append(ShopItem(reward: .levelUp, price: 100))
        }
        return items
    }

    /// Prefers events not seen yet in this run.
    public func event(state: RunState, catalog: GameCatalog, rng: inout SeededRandom) -> RunEvent {
        precondition(!catalog.events.isEmpty, "The catalog has no events")
        let unseen = catalog.events.filter { !state.seenEventIDs.contains($0.id) }
        let pool = unseen.isEmpty ? catalog.events : unseen
        return pool[Int.random(in: pool.indices, using: &rng)]
    }

    // MARK: - Helpers

    /// Distinct unowned relics; each pick rolls a rarity, falling back to any rarity when that pool is empty.
    public func randomRelics(_ count: Int, weights: [(Rarity, Int)], state: RunState, catalog: GameCatalog,
                             rng: inout SeededRandom) -> [Relic] {
        var available = catalog.relics.filter { !state.relicIDs.contains($0.id) }
        var picks: [Relic] = []
        while picks.count < count, !available.isEmpty {
            let rarity = weightedPick(weights, rng: &rng) ?? .common
            let ofRarity = available.indices.filter { available[$0].rarity == rarity }
            let indices = ofRarity.isEmpty ? Array(available.indices) : ofRarity
            picks.append(available.remove(at: indices[Int.random(in: indices.indices, using: &rng)]))
        }
        return picks
    }
}

func weightedPick<T>(_ options: [(T, Int)], rng: inout SeededRandom) -> T? {
    let total = options.reduce(0) { $0 + max(0, $1.1) }
    guard total > 0 else { return nil }
    var roll = Int.random(in: 0..<total, using: &rng)
    for (value, weight) in options where weight > 0 {
        roll -= weight
        if roll < 0 { return value }
    }
    return nil
}
