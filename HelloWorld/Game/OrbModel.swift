import Foundation

enum OrbType: Int, CaseIterable, Sendable {
    case fire, water, wood, light, dark, heal
}

/// Board coordinate. `row == 0` is the bottom row, `col == 0` the leftmost column.
struct GridPosition: Hashable, Sendable, CustomStringConvertible {
    let col: Int
    let row: Int

    /// True for the 8 surrounding cells (orthogonal or diagonal).
    func isAdjacent(to other: GridPosition) -> Bool {
        max(abs(col - other.col), abs(row - other.row)) == 1
    }

    var description: String { "(\(col), \(row))" }
}

struct Orb: Hashable, Identifiable, Sendable {
    let id: Int
    let type: OrbType
}

/// A single combo: an orthogonally connected group of same-type orbs that were part of 3+ lines.
struct MatchCluster: Sendable {
    let type: OrbType
    /// Sorted bottom-to-top, left-to-right.
    let positions: [GridPosition]
    let orbIDs: [Int]

    var count: Int { positions.count }
}

struct OrbFall: Sendable {
    let orbID: Int
    let from: GridPosition
    let to: GridPosition
}

struct OrbSpawn: Sendable {
    let orb: Orb
    let to: GridPosition
    /// 0 for the lowest new orb in its column, 1 for the one above it, etc.
    let stackIndex: Int
}

struct GravityResult: Sendable {
    let falls: [OrbFall]
    let spawns: [OrbSpawn]

    var isEmpty: Bool { falls.isEmpty && spawns.isEmpty }
}
