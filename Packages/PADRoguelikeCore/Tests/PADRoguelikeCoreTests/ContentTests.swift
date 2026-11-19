import Foundation
import Testing
@testable import PADRoguelikeCore

@Suite struct ContentTests {

    @Test func bundledContentLoadsAndIsConsistent() throws {
        let catalog = try GameCatalog.load()
        #expect(catalog.validate().isEmpty)
        #expect(catalog.characters.count == 6)
        #expect(catalog.relics.count == 24)
        #expect(catalog.enemies.count == 17)
        #expect(catalog.events.count == 8)
    }

    @Test func modifiersRoundTripThroughReadableJSON() throws {
        let all: [Modifier] = [
            .flatDamage(element: .fire, amount: 100), .flatDamage(element: nil, amount: -50),
            .damageMultiplier(element: nil, factor: 1.5),
            .clusterDamage(.orbsExactly(4), element: .water, factor: 2), .clusterDamage(.orbsAtMost(3), element: nil, factor: 0.8),
            .turnDamage(.matched([.fire, .light]), factor: 1.8), .turnDamage(.hpBelow(0.5), factor: 2),
            .comboBonus(0.1), .orbBonus(orb: .heal, amount: 0.2), .flatHeal(50), .healMultiplier(1.25),
            .maxHPMultiplier(0.7), .healOnTurnStart(100), .turnHeal(.colorsAtLeast(5), amount: 500),
            .hpLossOnTurnStart(80), .turnSelfDamage(.combosAtMost(2), amount: 400), .damageReduction(0.25),
            .damageTakenMultiplier(1.5), .shieldOnTurnStart(250), .turnShield(.orbsAtLeast(15), amount: 600), .moveTime(-1.5),
        ]
        let data = try JSONEncoder().encode(all)
        #expect(try JSONDecoder().decode([Modifier].self, from: data) == all)
    }

    @Test func handWrittenJSONReadsAsExpected() throws {
        let json = #"""
        [{"type": "clusterDamage", "when": {"orbsExactly": 4}, "factor": 1.5},
         {"type": "turnDamage", "when": {"matched": ["fire", "heal"]}, "factor": 2}]
        """#
        let modifiers = try JSONDecoder().decode([Modifier].self, from: Data(json.utf8))
        #expect(modifiers == [.clusterDamage(.orbsExactly(4), element: nil, factor: 1.5),
                              .turnDamage(.matched([.fire, .heal]), factor: 2)])

        let traits = try JSONDecoder().decode([EnemyTrait].self, from: Data(#"[{"absorb": "dark"}, {"comboShield": 3}]"#.utf8))
        #expect(traits == [.absorb(.dark), .comboShield(minCombos: 3)])
    }

    @Test func typosAreReportedWithFileAndPath() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for name in ["heroes", "enemies", "events"] {
            let source = try #require(Bundle.module(for: name))
            try FileManager.default.copyItem(at: source, to: directory.appendingPathComponent("\(name).json"))
        }

        let typo = #"[{"id": "x", "name": "X", "rarity": "rare", "modifiers": [{"type": "moveTime", "secnds": 1}]}]"#
        try Data(typo.utf8).write(to: directory.appendingPathComponent("relics.json"))
        let error = try #require(throws: CatalogError.self) { try GameCatalog.load(from: directory) }
        #expect(error.file == "relics.json")
        #expect(error.message.contains("[0].modifiers[0]"))
        #expect(error.message.contains("secnds"))

        let unknownType = #"[{"id": "x", "name": "X", "rarity": "rare", "modifiers": [{"type": "dmg", "factor": 2}]}]"#
        try Data(unknownType.utf8).write(to: directory.appendingPathComponent("relics.json"))
        let second = try #require(throws: CatalogError.self) { try GameCatalog.load(from: directory) }
        #expect(second.message.contains("Unknown modifier type \"dmg\""))
    }

    @Test func validationCatchesInconsistentData() throws {
        var catalog = try GameCatalog.load()
        catalog.relics.append(catalog.relics[0])
        catalog.enemies.removeAll { $0.tier == .boss }
        let problems = catalog.validate()
        #expect(problems.contains { $0.contains("relic id \"\(catalog.relics[0].id)\" is duplicated") })
        #expect(problems.contains("there are no boss enemies"))
    }
}

private extension Bundle {
    /// URL of a bundled content file, to build test fixtures.
    static func module(for name: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: "json")
    }
}
