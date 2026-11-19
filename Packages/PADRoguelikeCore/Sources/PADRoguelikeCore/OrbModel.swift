import Foundation

public enum OrbType: Int, CaseIterable, Codable, Sendable {
    case fire, water, wood, light, dark, heal
}

/// Board coordinate. `row == 0` is the bottom row, `col == 0` the leftmost column.
public struct GridPosition: Hashable, Sendable, CustomStringConvertible {
    public let col: Int
    public let row: Int

    public init(col: Int, row: Int) {
        self.col = col
        self.row = row
    }

    /// True for the 8 surrounding cells (orthogonal or diagonal).
    public func isAdjacent(to other: GridPosition) -> Bool {
        max(abs(col - other.col), abs(row - other.row)) == 1
    }

    public var description: String { "(\(col), \(row))" }
}

public struct Orb: Hashable, Identifiable, Sendable {
    public let id: Int
    public let type: OrbType
}

/// A single combo: an orthogonally connected group of same-type orbs that were part of 3+ lines.
public struct MatchCluster: Sendable {
    public let type: OrbType
    /// Sorted bottom-to-top, left-to-right.
    public let positions: [GridPosition]
    public let orbIDs: [Int]

    public init(type: OrbType, positions: [GridPosition], orbIDs: [Int] = []) {
        self.type = type
        self.positions = positions
        self.orbIDs = orbIDs
    }

    public var count: Int { positions.count }
}

public struct OrbFall: Sendable {
    public let orbID: Int
    public let from: GridPosition
    public let to: GridPosition
}

public struct OrbSpawn: Sendable {
    public let orb: Orb
    public let to: GridPosition
    /// 0 for the lowest new orb in its column, 1 for the one above it, etc.
    public let stackIndex: Int
}

public struct GravityResult: Sendable {
    public let falls: [OrbFall]
    public let spawns: [OrbSpawn]

    public var isEmpty: Bool { falls.isEmpty && spawns.isEmpty }
}

public struct OrbConversion: Sendable {
    public let position: GridPosition
    public let oldOrbID: Int
    public let orb: Orb
}
