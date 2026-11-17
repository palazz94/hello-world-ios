import Foundation

/// Pure board logic. No SpriteKit/UIKit, so it can be unit-tested in isolation.
final class BoardEngine {
    let cols: Int
    let rows: Int

    /// `grid[row][col]`, row 0 is the bottom.
    private(set) var grid: [[Orb?]]

    private var nextOrbID = 0
    /// Returns a value in `0..<upperBound`. Injectable for deterministic tests.
    private let randomIndex: (Int) -> Int

    init(cols: Int = 6,
         rows: Int = 5,
         randomIndex: @escaping (Int) -> Int = { Int.random(in: 0..<$0) }) {
        precondition(cols >= 3 && rows >= 3, "Board must be at least 3x3")
        self.cols = cols
        self.rows = rows
        self.randomIndex = randomIndex
        self.grid = Array(repeating: Array(repeating: nil, count: cols), count: rows)
        generateBoard()
    }

    // MARK: - Access

    func isValid(_ pos: GridPosition) -> Bool {
        (0..<cols).contains(pos.col) && (0..<rows).contains(pos.row)
    }

    func orb(at pos: GridPosition) -> Orb? {
        isValid(pos) ? grid[pos.row][pos.col] : nil
    }

    // MARK: - Generation

    /// Fills the board guaranteeing no pre-existing 3+ lines.
    func generateBoard() {
        for row in 0..<rows {
            for col in 0..<cols {
                var excluded = Set<OrbType>()
                if col >= 2,
                   let a = grid[row][col - 1], let b = grid[row][col - 2], a.type == b.type {
                    excluded.insert(a.type)
                }
                if row >= 2,
                   let a = grid[row - 1][col], let b = grid[row - 2][col], a.type == b.type {
                    excluded.insert(a.type)
                }
                let allowed = OrbType.allCases.filter { !excluded.contains($0) }
                grid[row][col] = makeOrb(allowed[randomIndex(allowed.count)])
            }
        }
    }

    // MARK: - Swap

    /// Swaps two orbs if both positions are valid and adjacent (8-neighbourhood).
    @discardableResult
    func swap(_ a: GridPosition, _ b: GridPosition) -> Bool {
        guard isValid(a), isValid(b), a.isAdjacent(to: b) else { return false }
        let tmp = grid[a.row][a.col]
        grid[a.row][a.col] = grid[b.row][b.col]
        grid[b.row][b.col] = tmp
        return true
    }

    // MARK: - Matching

    /// Returns combo clusters ordered bottom-to-top, left-to-right (by each cluster's lowest-leftmost orb).
    func findMatches() -> [MatchCluster] {
        var marked = Array(repeating: Array(repeating: false, count: cols), count: rows)

        for row in 0..<rows {
            var start = 0
            while start < cols {
                guard let type = grid[row][start]?.type else { start += 1; continue }
                var end = start + 1
                while end < cols, grid[row][end]?.type == type { end += 1 }
                if end - start >= 3 {
                    for col in start..<end { marked[row][col] = true }
                }
                start = end
            }
        }

        for col in 0..<cols {
            var start = 0
            while start < rows {
                guard let type = grid[start][col]?.type else { start += 1; continue }
                var end = start + 1
                while end < rows, grid[end][col]?.type == type { end += 1 }
                if end - start >= 3 {
                    for row in start..<end { marked[row][col] = true }
                }
                start = end
            }
        }

        // BFS over marked cells: touching same-type lines (L, T, +) merge into one combo.
        var visited = Array(repeating: Array(repeating: false, count: cols), count: rows)
        var clusters: [MatchCluster] = []
        let neighbours = [(1, 0), (-1, 0), (0, 1), (0, -1)]

        for row in 0..<rows {
            for col in 0..<cols {
                guard marked[row][col], !visited[row][col], let type = grid[row][col]?.type else { continue }

                var queue = [GridPosition(col: col, row: row)]
                var head = 0
                visited[row][col] = true

                while head < queue.count {
                    let current = queue[head]
                    head += 1
                    for (dc, dr) in neighbours {
                        let next = GridPosition(col: current.col + dc, row: current.row + dr)
                        guard isValid(next),
                              marked[next.row][next.col],
                              !visited[next.row][next.col],
                              grid[next.row][next.col]?.type == type else { continue }
                        visited[next.row][next.col] = true
                        queue.append(next)
                    }
                }

                let sorted = queue.sorted { ($0.row, $0.col) < ($1.row, $1.col) }
                clusters.append(MatchCluster(
                    type: type,
                    positions: sorted,
                    orbIDs: sorted.compactMap { grid[$0.row][$0.col]?.id }
                ))
            }
        }
        return clusters
    }

    func removeOrbs(in clusters: [MatchCluster]) {
        for cluster in clusters {
            for pos in cluster.positions where isValid(pos) {
                grid[pos.row][pos.col] = nil
            }
        }
    }

    // MARK: - Gravity & Skyfall

    /// Drops existing orbs into empty cells and fills the remaining top cells with new random orbs.
    func applyGravity() -> GravityResult {
        var falls: [OrbFall] = []
        var spawns: [OrbSpawn] = []

        for col in 0..<cols {
            var write = 0
            for read in 0..<rows {
                guard let orb = grid[read][col] else { continue }
                if read != write {
                    grid[write][col] = orb
                    grid[read][col] = nil
                    falls.append(OrbFall(orbID: orb.id,
                                         from: GridPosition(col: col, row: read),
                                         to: GridPosition(col: col, row: write)))
                }
                write += 1
            }
            for (index, row) in (write..<rows).enumerated() {
                let orb = makeOrb(OrbType.allCases[randomIndex(OrbType.allCases.count)])
                grid[row][col] = orb
                spawns.append(OrbSpawn(orb: orb, to: GridPosition(col: col, row: row), stackIndex: index))
            }
        }
        return GravityResult(falls: falls, spawns: spawns)
    }

    // MARK: - Private

    private func makeOrb(_ type: OrbType) -> Orb {
        defer { nextOrbID += 1 }
        return Orb(id: nextOrbID, type: type)
    }
}
