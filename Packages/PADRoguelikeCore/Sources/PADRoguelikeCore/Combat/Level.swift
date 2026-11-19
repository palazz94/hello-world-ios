import Foundation

public struct Level: Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let mode: EncounterMode
    public let enemies: [Enemy]

    public init(id: Int, name: String, mode: EncounterMode, enemies: [Enemy]) {
        precondition(!enemies.isEmpty, "A level needs at least one enemy")
        self.id = id
        self.name = name
        self.mode = mode
        self.enemies = enemies
    }
}

public extension Level {
    static let campaign: [Level] = [
        Level(id: 0, name: "Prato", mode: .sequential, enemies: [
            Enemy(id: 0, name: "Slime", element: .wood, maxHP: 1_500, attackPower: 300, turnInterval: 1),
            Enemy(id: 1, name: "Slime", element: .wood, maxHP: 1_500, attackPower: 300, turnInterval: 1),
        ]),
        Level(id: 1, name: "Lago", mode: .simultaneous, enemies: [
            Enemy(id: 0, name: "Slime", element: .wood, maxHP: 1_500, attackPower: 300, turnInterval: 1),
            Enemy(id: 1, name: "Golem", element: .water, maxHP: 6_000, attackPower: 900, turnInterval: 2),
        ]),
        Level(id: 2, name: "Caverna", mode: .simultaneous, enemies: Enemy.testRoster),
        Level(id: 3, name: "Tana del Drago", mode: .sequential, enemies: [
            Enemy(id: 0, name: "Golem", element: .water, maxHP: 6_000, attackPower: 900, turnInterval: 2),
            Enemy(id: 1, name: "Drago Antico", element: .fire, maxHP: 30_000, attackPower: 3_000, turnInterval: 3),
        ]),
    ]
}
