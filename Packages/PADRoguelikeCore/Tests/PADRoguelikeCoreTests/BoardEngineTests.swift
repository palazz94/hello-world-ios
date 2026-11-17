import Testing
@testable import PADRoguelikeCore

/// F fire, W water, G wood (green), L light, D dark, H heal. First string is the top row.
private func makeEngine(_ rows: String...) -> BoardEngine {
    let map: [Character: OrbType] = ["F": .fire, "W": .water, "G": .wood, "L": .light, "D": .dark, "H": .heal]
    return BoardEngine(layout: rows.map { $0.map { map[$0]! } })
}

@Suite struct BoardEngineTests {

    @Test func initialBoardHasNoMatches() {
        for _ in 0..<500 {
            #expect(BoardEngine().findMatches().isEmpty)
        }
    }

    @Test func initialBoardHasNoMatchesWithDegenerateRandom() {
        #expect(BoardEngine(randomIndex: { _ in 0 }).findMatches().isEmpty)
    }

    @Test func swapAllowsOrthogonalAndDiagonalOnly() {
        let engine = BoardEngine()
        let origin = GridPosition(col: 1, row: 1)
        #expect(engine.swap(origin, GridPosition(col: 2, row: 1)))
        #expect(engine.swap(origin, GridPosition(col: 2, row: 2)))
        #expect(!engine.swap(origin, GridPosition(col: 3, row: 1)))
        #expect(!engine.swap(origin, origin))
        #expect(!engine.swap(GridPosition(col: 0, row: 0), GridPosition(col: -1, row: 0)))
    }

    @Test func swapExchangesOrbs() {
        let engine = BoardEngine()
        let a = GridPosition(col: 0, row: 0), b = GridPosition(col: 1, row: 1)
        let (orbA, orbB) = (engine.orb(at: a), engine.orb(at: b))
        engine.swap(a, b)
        #expect(engine.orb(at: a) == orbB)
        #expect(engine.orb(at: b) == orbA)
    }

    @Test func twoInARowIsNotAMatch() {
        let engine = makeEngine("WGL",
                                "GLW",
                                "FFD")
        #expect(engine.findMatches().isEmpty)
    }

    @Test func horizontalLineIsOneCluster() {
        let engine = makeEngine("WGL",
                                "GLW",
                                "FFF")
        let clusters = engine.findMatches()
        #expect(clusters.count == 1)
        #expect(clusters[0].type == .fire)
        #expect(clusters[0].count == 3)
    }

    @Test func lShapeIsOneCluster() {
        let engine = makeEngine("WLWL",
                                "FGDH",
                                "FLWG",
                                "FFFD")
        let clusters = engine.findMatches()
        #expect(clusters.count == 1)
        #expect(clusters[0].count == 5)
    }

    @Test func crossIsOneCluster() {
        let engine = makeEngine("WFL",
                                "FFF",
                                "DFH")
        let clusters = engine.findMatches()
        #expect(clusters.count == 1)
        #expect(clusters[0].count == 5)
    }

    @Test func clustersAreOrderedBottomToTop() {
        let engine = makeEngine("FFF",
                                "WGL",
                                "GLW",
                                "LWG",
                                "HHH")
        let clusters = engine.findMatches()
        #expect(clusters.map(\.type) == [.heal, .fire])
    }

    @Test func gravityCompactsColumnAndSpawnsOnTop() {
        let engine = BoardEngine(cols: 6, rows: 5)
        let top = engine.orb(at: GridPosition(col: 0, row: 4))!
        let removed = MatchCluster(type: .fire, positions: [GridPosition(col: 0, row: 0)], orbIDs: [])
        engine.removeOrbs(in: [removed])

        let result = engine.applyGravity()

        #expect(result.falls.count == 4)
        #expect(result.spawns.count == 1)
        #expect(result.spawns[0].to == GridPosition(col: 0, row: 4))
        #expect(result.spawns[0].stackIndex == 0)
        #expect(result.falls.last?.orbID == top.id)
        #expect(result.falls.last?.to == GridPosition(col: 0, row: 3))
        #expect((0..<5).allSatisfy { engine.orb(at: GridPosition(col: 0, row: $0)) != nil })
    }

    @Test func cascadeLoopTerminatesWithFullBoard() {
        for _ in 0..<200 {
            let engine = BoardEngine()
            engine.swap(GridPosition(col: 2, row: 2), GridPosition(col: 3, row: 3))

            var iterations = 0
            while case let clusters = engine.findMatches(), !clusters.isEmpty {
                engine.removeOrbs(in: clusters)
                _ = engine.applyGravity()
                iterations += 1
                #expect(iterations < 100)
                if iterations >= 100 { break }
            }
            #expect(engine.grid.allSatisfy { $0.allSatisfy { $0 != nil } })
        }
    }
}
