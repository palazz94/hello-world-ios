import Testing
@testable import GameCore

@Test func initialBoardHasNoMatches() {
    for _ in 0..<200 {
        let board = BoardLogic(cols: 6, rows: 5)
        #expect(board.findCombos().isEmpty)
        #expect(board.allOrbs.count == 30)
    }
}

@Test func crossShapeIsOneCombo() {
    let board = BoardLogic(types: [
        [.water, .fire, .water, .wood],
        [.fire, .fire, .fire, .wood],
        [.water, .fire, .water, .light],
    ])
    let combos = board.findCombos()
    #expect(combos.count == 1)
    #expect(combos.first?.orbs.count == 5)
}

@Test func lShapeOfThreeIsNotAMatch() {
    let board = BoardLogic(types: [
        [.fire, .water, .wood],
        [.fire, .fire, .light],
        [.water, .wood, .light],
    ])
    #expect(board.findCombos().isEmpty)
}

@Test func gravityAndRefillFillEveryCell() {
    let board = BoardLogic(types: [
        [.water, .wood, .light],
        [.fire, .fire, .fire],
        [.wood, .light, .water],
    ])
    let combo = try! #require(board.findCombos().first)
    board.remove(combo.orbs)
    let drops = board.applyGravityAndRefill()

    #expect(board.allOrbs.count == 9)
    #expect(drops.filter(\.isNew).count == 3)
    for orb in board.allOrbs {
        #expect(board.orb(at: orb.position) === orb)
    }
}

@Test func swapRejectsNonAdjacentCells() {
    let board = BoardLogic(cols: 6, rows: 5)
    #expect(board.swap(GridPosition(col: 0, row: 0), GridPosition(col: 1, row: 1)))
    #expect(!board.swap(GridPosition(col: 0, row: 0), GridPosition(col: 2, row: 0)))
}
