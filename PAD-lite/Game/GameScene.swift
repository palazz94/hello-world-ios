import PADRoguelikeCore
import SpriteKit
import UIKit

/// Board placement in scene coordinates (SpriteKit, y-up). Computed by `GameViewController`.
struct BoardLayout: Equatable {
    var origin: CGPoint
    var cellSize: CGFloat
    var timerBarHeight: CGFloat
    var timerBarGap: CGFloat
    /// Safe-area inset at the top of the scene.
    var topInset: CGFloat
}

/// Board scene: grid rendering, drag input and combo resolution. Subclass and override the hooks to add game modes.
@MainActor
class GameScene: SKScene {

    enum State { case idle, dragging, resolving }

    private enum Z {
        static let tiles: CGFloat = 0
        static let orbs: CGFloat = 10
        static let popping: CGFloat = 20
        static let dragged: CGFloat = 100
        static let hud: CGFloat = 200
    }

    private enum Timing {
        static let swap: TimeInterval = 0.08
        static let comboInterval: TimeInterval = 0.25
        static let pop: TimeInterval = 0.2
        static let settle: TimeInterval = 0.06
        static let cascadePause: TimeInterval = 0.08
    }

    private enum Tuning {
        static let dragScale: CGFloat = 1.15
        static let dragAlpha: CGFloat = 0.85
        /// Finger must be within this fraction of the target cell's half-size from its centre to swap.
        static let swapZone: CGFloat = 0.75
    }

    private static let swapActionKey = "swap"

    let engine: BoardEngine
    private(set) var state: State = .idle
    /// When true, new drags are ignored (e.g. during enemy turns or game over).
    var isInputLocked = false
    /// Seconds available to move orbs, counted from the first swap.
    var moveDuration: TimeInterval = 5.0
    var hapticsEnabled = true

    private var layout: BoardLayout?
    private var pendingLayout: BoardLayout?

    private let boardLayer = SKNode()
    private let tileLayer = SKNode()
    private let orbCrop = SKCropNode()
    private let orbLayer = SKNode()
    private let timerTrack = SKShapeNode()
    private let timerFill = SKSpriteNode(color: .white, size: .zero)
    private let comboLabel = SKLabelNode(fontNamed: "AvenirNext-HeavyItalic")

    private var orbNodes: [Int: SKSpriteNode] = [:]
    private var orbTextures: [OrbType: SKTexture] = [:]

    private var activeTouch: UITouch?
    private var heldOrbID: Int?
    private var heldPosition: GridPosition?
    private var moveDeadline: TimeInterval?
    private var comboCount = 0

    private let swapFeedback = UIImpactFeedbackGenerator(style: .light)
    private let comboHaptics = ComboHaptics()

    // MARK: - Init

    init(engine: BoardEngine) {
        self.engine = engine
        super.init(size: CGSize(width: 1, height: 1))
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = UIColor(red: 0.07, green: 0.06, blue: 0.12, alpha: 1)
        buildHierarchy()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        comboHaptics.prepare()
    }

    // MARK: - Layout

    func apply(layout newLayout: BoardLayout) {
        guard newLayout != layout else { return }
        guard state == .idle else {
            pendingLayout = newLayout
            return
        }
        layout = newLayout
        rebuildBoard()
    }

    private func buildHierarchy() {
        addChild(boardLayer)

        tileLayer.zPosition = Z.tiles
        boardLayer.addChild(tileLayer)

        orbCrop.zPosition = Z.orbs
        orbCrop.addChild(orbLayer)
        boardLayer.addChild(orbCrop)

        timerTrack.fillColor = UIColor.white.withAlphaComponent(0.12)
        timerTrack.strokeColor = .clear
        timerTrack.zPosition = Z.hud
        timerFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        timerFill.zPosition = 1
        timerTrack.addChild(timerFill)
        addChild(timerTrack)

        comboLabel.fontColor = .white
        comboLabel.horizontalAlignmentMode = .center
        comboLabel.verticalAlignmentMode = .center
        comboLabel.zPosition = Z.hud
        comboLabel.alpha = 0
        addChild(comboLabel)
    }

    private func rebuildBoard() {
        guard let layout else { return }
        let cell = layout.cellSize
        let boardSize = CGSize(width: cell * CGFloat(engine.cols), height: cell * CGFloat(engine.rows))

        boardLayer.position = layout.origin

        // Background tiles
        tileLayer.removeAllChildren()
        let frame = SKShapeNode(rect: CGRect(origin: .zero, size: boardSize).insetBy(dx: -4, dy: -4),
                                cornerRadius: 8)
        frame.fillColor = UIColor(red: 0.04, green: 0.03, blue: 0.07, alpha: 1)
        frame.strokeColor = UIColor.white.withAlphaComponent(0.15)
        frame.lineWidth = 2
        frame.zPosition = -1
        tileLayer.addChild(frame)

        let tileA = UIColor(red: 0.17, green: 0.13, blue: 0.22, alpha: 1)
        let tileB = UIColor(red: 0.12, green: 0.09, blue: 0.16, alpha: 1)
        for row in 0..<engine.rows {
            for col in 0..<engine.cols {
                let tile = SKSpriteNode(color: (row + col).isMultiple(of: 2) ? tileA : tileB,
                                        size: CGSize(width: cell, height: cell))
                tile.position = center(of: GridPosition(col: col, row: row))
                tileLayer.addChild(tile)
            }
        }

        let mask = SKSpriteNode(color: .white, size: boardSize)
        mask.anchorPoint = .zero
        orbCrop.maskNode = mask

        // Orbs
        orbTextures = makeOrbTextures()
        placeOrbs()

        // HUD: timer bar directly above the board, combo label above it.
        let barHeight = layout.timerBarHeight
        let barY = layout.origin.y + boardSize.height + layout.timerBarGap + barHeight / 2
        timerTrack.path = CGPath(roundedRect: CGRect(x: -boardSize.width / 2, y: -barHeight / 2,
                                                     width: boardSize.width, height: barHeight),
                                 cornerWidth: barHeight / 2, cornerHeight: barHeight / 2, transform: nil)
        timerTrack.position = CGPoint(x: layout.origin.x + boardSize.width / 2, y: barY)
        timerFill.size = CGSize(width: boardSize.width, height: barHeight)
        timerFill.position = CGPoint(x: -boardSize.width / 2, y: 0)
        resetTimerBar()

        comboLabel.fontSize = cell * 0.55
        comboLabel.position = CGPoint(x: timerTrack.position.x, y: barY + barHeight / 2 + cell * 0.5)

        boardLayoutDidChange(layout,
                             boardFrame: CGRect(origin: layout.origin, size: boardSize),
                             hudTop: comboLabel.position.y + cell * 0.5)
    }

    // MARK: - Subclass hooks

    /// Called after every layout rebuild. `hudTop` is the first free y above the timer bar and combo label.
    func boardLayoutDidChange(_ layout: BoardLayout, boardFrame: CGRect, hudTop: CGFloat) {}

    /// Called once per player move, after all cascades, with every combo in pop order.
    func boardDidFinishTurn(_ clusters: [MatchCluster]) {}

    /// Regenerates a fresh board without matches. Ignored unless idle.
    func resetBoard() {
        guard state == .idle else { return }
        engine.generateBoard()
        rebuildBoard()
    }

    /// Redraws every orb from the engine after something outside the drag changed it (e.g. an ability).
    func reloadOrbs() {
        guard state == .idle, layout != nil else { return }
        placeOrbs()
        for node in orbNodes.values {
            node.setScale(0.6)
            node.run(.scale(to: 1, duration: 0.15))
        }
    }

    private func placeOrbs() {
        orbLayer.removeAllChildren()
        orbNodes.removeAll()
        for row in 0..<engine.rows {
            for col in 0..<engine.cols {
                let pos = GridPosition(col: col, row: row)
                guard let orb = engine.orb(at: pos) else { continue }
                let node = makeOrbNode(orb)
                node.position = center(of: pos)
                orbLayer.addChild(node)
                orbNodes[orb.id] = node
            }
        }
    }

    // MARK: - Geometry

    private var cellSize: CGFloat { layout?.cellSize ?? 0 }

    /// Centre of a cell in board-local coordinates. Rows >= `engine.rows` are valid for skyfall spawns.
    private func center(of pos: GridPosition) -> CGPoint {
        CGPoint(x: (CGFloat(pos.col) + 0.5) * cellSize, y: (CGFloat(pos.row) + 0.5) * cellSize)
    }

    private func gridPosition(at point: CGPoint) -> GridPosition? {
        guard cellSize > 0 else { return nil }
        let pos = GridPosition(col: Int(floor(point.x / cellSize)), row: Int(floor(point.y / cellSize)))
        return engine.isValid(pos) ? pos : nil
    }

    /// Keeps the dragged orb's centre inside the board.
    private func clampedDragPoint(_ point: CGPoint) -> CGPoint {
        let half = cellSize / 2
        let maxX = cellSize * CGFloat(engine.cols) - half
        let maxY = cellSize * CGFloat(engine.rows) - half
        return CGPoint(x: min(max(point.x, half), maxX), y: min(max(point.y, half), maxY))
    }

    private func isInsideSwapZone(_ point: CGPoint, of pos: GridPosition) -> Bool {
        let c = center(of: pos)
        let limit = cellSize / 2 * Tuning.swapZone
        return abs(point.x - c.x) <= limit && abs(point.y - c.y) <= limit
    }

    // MARK: - Touch input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard state == .idle, !isInputLocked, activeTouch == nil, layout != nil,
              let touch = touches.first else { return }
        let point = touch.location(in: orbLayer)
        guard let pos = gridPosition(at: point),
              let orb = engine.orb(at: pos),
              let node = orbNodes[orb.id] else { return }

        state = .dragging
        activeTouch = touch
        heldOrbID = orb.id
        heldPosition = pos
        moveDeadline = nil

        node.removeAllActions()
        node.zPosition = Z.dragged
        node.setScale(Tuning.dragScale)
        node.alpha = Tuning.dragAlpha
        node.position = clampedDragPoint(point)
        swapFeedback.prepare()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard state == .dragging, let touch = activeTouch, touches.contains(touch) else { return }

        // Coalesced samples (up to 240Hz on ProMotion) keep fast diagonal drags from skipping cells.
        let samples = event?.coalescedTouches(for: touch) ?? [touch]
        for sample in samples {
            trackDrag(to: clampedDragPoint(sample.location(in: orbLayer)))
        }

        if let id = heldOrbID, let node = orbNodes[id] {
            node.position = clampedDragPoint(touch.location(in: orbLayer))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        finishDrag()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        finishDrag()
    }

    private func trackDrag(to point: CGPoint) {
        guard state == .dragging,
              var current = heldPosition,
              let target = gridPosition(at: point) else { return }

        // Walk one cell at a time so even a large jump produces a valid chain of adjacent swaps.
        while current != target {
            let next = GridPosition(col: current.col + (target.col - current.col).signum(),
                                    row: current.row + (target.row - current.row).signum())
            if next == target, !isInsideSwapZone(point, of: next) { break }
            guard swapHeldOrb(from: current, to: next) else { break }
            current = next
        }
    }

    private func swapHeldOrb(from: GridPosition, to: GridPosition) -> Bool {
        guard engine.swap(from, to) else { return false }
        heldPosition = to

        if moveDeadline == nil {
            moveDeadline = CACurrentMediaTime() + moveDuration
        }

        if let displaced = engine.orb(at: from), let node = orbNodes[displaced.id] {
            node.removeAction(forKey: Self.swapActionKey)
            let move = SKAction.move(to: center(of: from), duration: Timing.swap)
            move.timingMode = .easeOut
            node.run(move, withKey: Self.swapActionKey)
        }

        if hapticsEnabled {
            swapFeedback.impactOccurred()
            swapFeedback.prepare()
        }
        return true
    }

    private func finishDrag() {
        guard state == .dragging else { return }
        state = .resolving

        let didSwap = moveDeadline != nil
        activeTouch = nil
        moveDeadline = nil
        resetTimerBar()

        if let id = heldOrbID, let pos = heldPosition, let node = orbNodes[id] {
            node.zPosition = Z.orbs
            node.run(.group([
                .move(to: center(of: pos), duration: Timing.settle),
                .scale(to: 1, duration: Timing.settle),
                .fadeAlpha(to: 1, duration: Timing.settle)
            ]))
        }
        heldOrbID = nil
        heldPosition = nil

        guard didSwap else {
            enterIdle()
            return
        }
        Task { [weak self] in
            await self?.resolveBoard()
        }
    }

    // MARK: - Frame update / timer

    override func update(_ currentTime: TimeInterval) {
        guard state == .dragging, let deadline = moveDeadline else { return }
        let remaining = deadline - CACurrentMediaTime()
        updateTimerBar(fraction: CGFloat(max(0, remaining / moveDuration)))
        if remaining <= 0 { finishDrag() }
    }

    private func updateTimerBar(fraction: CGFloat) {
        timerFill.xScale = fraction
        switch fraction {
        case 0.5...: timerFill.color = UIColor(red: 0.30, green: 0.85, blue: 0.45, alpha: 1)
        case 0.25..<0.5: timerFill.color = UIColor(red: 0.98, green: 0.78, blue: 0.20, alpha: 1)
        default: timerFill.color = UIColor(red: 0.95, green: 0.27, blue: 0.24, alpha: 1)
        }
    }

    private func resetTimerBar() {
        timerFill.xScale = 1
        timerFill.color = UIColor.white.withAlphaComponent(0.25)
    }

    // MARK: - Resolution

    private func resolveBoard() async {
        comboCount = 0
        var turnClusters: [MatchCluster] = []
        await wait(Timing.settle)

        while true {
            let clusters = engine.findMatches()
            guard !clusters.isEmpty else { break }
            turnClusters += clusters

            for cluster in clusters {
                comboCount += 1
                pop(cluster)
                showCombo(comboCount)
                if hapticsEnabled { comboHaptics.play(combo: comboCount) }
                await wait(Timing.comboInterval)
            }

            engine.removeOrbs(in: clusters)
            let fallTime = animateGravity(engine.applyGravity())
            await wait(fallTime + Timing.cascadePause)
        }

        if comboCount > 0 { fadeOutCombo() }
        enterIdle()
        boardDidFinishTurn(turnClusters)
    }

    private func enterIdle() {
        state = .idle
        if let pending = pendingLayout {
            pendingLayout = nil
            apply(layout: pending)
        }
    }

    /// Scene-clock wait so it pauses along with the scene.
    func wait(_ duration: TimeInterval) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            run(.wait(forDuration: duration)) { continuation.resume() }
        }
    }

    private func pop(_ cluster: MatchCluster) {
        for id in cluster.orbIDs {
            guard let node = orbNodes.removeValue(forKey: id) else { continue }
            node.removeAllActions()
            node.zPosition = Z.popping
            let burst = SKAction.group([
                .scale(to: 1.35, duration: Timing.pop),
                .fadeOut(withDuration: Timing.pop)
            ])
            burst.timingMode = .easeOut
            node.run(.sequence([burst, .removeFromParent()]))
        }
    }

    private func showCombo(_ count: Int) {
        comboLabel.text = "\(count) Combo"
        comboLabel.removeAllActions()
        comboLabel.alpha = 1
        comboLabel.setScale(1.35)
        let settle = SKAction.scale(to: 1, duration: 0.12)
        settle.timingMode = .easeOut
        comboLabel.run(settle)
    }

    // Kept synchronous: inside an async context `run(_:)` would resolve to SpriteKit's async overload.
    private func fadeOutCombo() {
        comboLabel.run(.sequence([.wait(forDuration: 0.8), .fadeOut(withDuration: 0.3)]))
    }

    /// Starts gravity/skyfall animations and returns the longest duration.
    private func animateGravity(_ result: GravityResult) -> TimeInterval {
        var longest: TimeInterval = 0

        for fall in result.falls {
            guard let node = orbNodes[fall.orbID] else { continue }
            let (action, duration) = fallAction(to: center(of: fall.to), rows: fall.from.row - fall.to.row)
            node.removeAllActions()
            node.run(action)
            longest = max(longest, duration)
        }

        for spawn in result.spawns {
            let node = makeOrbNode(spawn.orb)
            let startRow = engine.rows + spawn.stackIndex
            node.position = center(of: GridPosition(col: spawn.to.col, row: startRow))
            orbLayer.addChild(node)
            orbNodes[spawn.orb.id] = node

            let (action, duration) = fallAction(to: center(of: spawn.to), rows: startRow - spawn.to.row)
            node.run(action)
            longest = max(longest, duration)
        }
        return longest
    }

    private func fallAction(to point: CGPoint, rows: Int) -> (SKAction, TimeInterval) {
        let fallTime = 0.08 + 0.1 * sqrt(Double(max(rows, 1)))
        let move = SKAction.move(to: point, duration: fallTime)
        move.timingMode = .easeIn
        let squash = SKAction.scaleX(to: 1.06, y: 0.92, duration: 0.05)
        let restore = SKAction.scale(to: 1, duration: 0.07)
        return (.sequence([move, squash, restore]), fallTime + 0.12)
    }

    // MARK: - Orb nodes

    /// Gems are drawn with a glow margin, so the texture is almost a full cell.
    private var orbSide: CGFloat { cellSize * 0.98 }

    private func makeOrbTextures() -> [OrbType: SKTexture] {
        guard orbSide > 0 else { return [:] }
        let scale = view?.contentScaleFactor ?? 3
        var textures: [OrbType: SKTexture] = [:]
        for type in OrbType.allCases {
            textures[type] = OrbArtwork.texture(for: type, diameter: orbSide, scale: scale)
        }
        return textures
    }

    private func makeOrbNode(_ orb: Orb) -> SKSpriteNode {
        let texture = orbTextures[orb.type]
            ?? OrbArtwork.texture(for: orb.type, diameter: orbSide, scale: view?.contentScaleFactor ?? 3)
        let node = SKSpriteNode(texture: texture, size: CGSize(width: orbSide, height: orbSide))
        node.zPosition = Z.orbs
        return node
    }
}
