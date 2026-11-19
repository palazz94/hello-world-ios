import Foundation

public enum NodeKind: String, Codable, CaseIterable, Sendable {
    case combat, elite, event, shop, rest, treasure, boss

    public var isCombat: Bool { self == .combat || self == .elite || self == .boss }
}

public struct MapNode: Hashable, Codable, Sendable, Identifiable {
    public let id: Int
    public let row: Int
    public let column: Int
    public let kind: NodeKind
    /// Ids of the nodes reachable from here, in the next row.
    public let next: [Int]

    public init(id: Int, row: Int, column: Int, kind: NodeKind, next: [Int]) {
        self.id = id
        self.row = row
        self.column = column
        self.kind = kind
        self.next = next
    }
}

/// Branching map in the style of Slay the Spire: rows from bottom (0) to the boss on top. Node ids equal their index.
public struct RunMap: Hashable, Codable, Sendable {
    public let columns: Int
    public let nodes: [MapNode]

    public init(columns: Int, nodes: [MapNode]) {
        self.columns = columns
        self.nodes = nodes
    }

    public var rowCount: Int { (nodes.map(\.row).max() ?? -1) + 1 }

    public func node(_ id: Int) -> MapNode? {
        nodes.indices.contains(id) ? nodes[id] : nil
    }

    public func nodes(inRow row: Int) -> [MapNode] {
        nodes.filter { $0.row == row }
    }
}
