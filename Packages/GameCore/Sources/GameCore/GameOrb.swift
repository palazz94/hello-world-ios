import Foundation

public struct GameOrb: Identifiable {
    public let id = UUID()
    public let type: String // e.g., "fire", "water", "nature"
    public var level: Int // e.g., 1, 2, 3

    public init(type: String, level: Int) {
        self.type = type
        self.level = level
    }
}