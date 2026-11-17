//  GameScene.swift
//  HelloWorld
//
//  La scena SpriteKit principale. Fa da "regista":
//  - riceve i touch e li traduce in azioni sul modello (BoardLogic);
//  - chiede al modello cosa è cambiato e lo anima con gli OrbNode;
//  - gestisce la macchina a stati del turno, il timer e l'aptica.

import SpriteKit
import UIKit
import GameCore

final class GameScene: SKScene {

    // MARK: - Macchina a stati

    /// Gli stati del turno. Avere UNO stato esplicito (invece di tanti Bool
    /// tipo isDragging, isResolving...) rende impossibili combinazioni assurde
    /// e ogni metodo può semplicemente chiedersi "in che stato sono?".
    enum State: String {
        case idle              // in attesa del tocco
        case dragging          // il giocatore sta trascinando un globo
        case resolvingMatches  // rimozione delle combo, una alla volta
        case skyfall           // caduta dei globi e generazione dei nuovi
    }

    private var state: State = .idle {
        // `didSet` scatta a ogni cambio di stato: un unico punto per il log.
        didSet {
            if oldValue != state { print("[Scene] Stato: \(oldValue.rawValue) -> \(state.rawValue)") }
        }
    }

    // MARK: - Configurazione (valori da "tarare" giocando)

    private let turnDuration: TimeInterval = 5.0
    /// Il globo trascinato sta 20pt SOPRA il dito, così il polpastrello non lo copre.
    private let dragOffsetY: CGFloat = 20
    /// Raggio della hitbox circolare al centro di ogni cella, in % del lato cella.
    /// Più piccolo del mezzo lato (0.5) → gli angoli delle celle sono "zona morta",
    /// quindi passando vicino a un angolo non si scambia per sbaglio in diagonale.
    private let swapHitRadiusRatio: CGFloat = 0.38
    private let comboStepDuration: TimeInterval = 0.25
    private let orbSizeRatio: CGFloat = 0.86

    /// Colore di sfondo, esposto per colorare uguale anche l'area SwiftUI attorno.
    static let backgroundTint = UIColor(red: 0.08, green: 0.07, blue: 0.13, alpha: 1)

    // MARK: - Modello e collegamento Model ↔ View

    private let board = BoardLogic(cols: 6, rows: 5)
    /// Dizionario id del globo → suo nodo grafico. È così che, quando il modello
    /// dice "il globo X si è spostato", troviamo subito il nodo da animare.
    private var orbNodes: [UUID: OrbNode] = [:]

    // MARK: - Layout (ricalcolato a ogni cambio di dimensione)

    private var cellSize: CGFloat = 0
    private var boardOrigin: CGPoint = .zero   // angolo in basso a sinistra della griglia
    private var timerBarFullWidth: CGFloat = 0
    /// Se lo schermo cambia dimensione durante un'animazione, rimandiamo il
    /// riposizionamento dei globi alla fine del turno per non "rompere" le animazioni.
    private var needsOrbRelayout = false

    private var boardRect: CGRect {
        CGRect(x: boardOrigin.x, y: boardOrigin.y,
               width: cellSize * CGFloat(board.cols),
               height: cellSize * CGFloat(board.rows))
    }

    // MARK: - Nodi grafici fissi

    private let cellsLayer = SKNode()          // le caselle a scacchiera
    private let cropNode = SKCropNode()        // "ritaglia" i globi dentro il tabellone
    private let orbsLayer = SKNode()           // contenitore dei globi
    private let timerBarBackground = SKShapeNode()
    private let timerBarFill = SKSpriteNode(color: .systemGreen, size: .zero)
    private let comboLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let hintLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")

    // MARK: - Stato del trascinamento

    /// Il dito che sta trascinando: ignoriamo eventuali altri dita.
    private var activeTouch: UITouch?
    private var heldNode: OrbNode?
    /// La cella in cui si trova ADESSO il globo trascinato (cambia a ogni scambio).
    private var heldPosition: GridPosition?
    private var timerStarted = false
    private var timeRemaining: TimeInterval = 0
    private var lastUpdateTime: TimeInterval?

    private var comboCount = 0
    private var isSetUp = false

    /// Generatore di vibrazione leggera. `prepare()` "scalda" il motore aptico
    /// in anticipo, così la vibrazione parte senza ritardo al momento dello scambio.
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    // MARK: - Init

    override init(size: CGSize) {
        super.init(size: size)
        // `.resizeFill`: la scena assume sempre la dimensione esatta della view.
        // Così non ci sono bande nere né stiramenti, e su un foldable che si
        // apre riceviamo `didChangeSize` e ricalcoliamo il layout.
        scaleMode = .resizeFill
        backgroundColor = Self.backgroundTint
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("GameScene viene creata solo da codice")
    }

    // MARK: - Ciclo di vita della scena

    /// Chiamato quando la scena viene mostrata in una SKView.
    override func didMove(to view: SKView) {
        // SwiftUI può ripresentare la stessa scena: costruiamo i nodi una volta sola.
        guard !isSetUp else { return }
        isSetUp = true

        addChild(cellsLayer)
        cropNode.addChild(orbsLayer)
        addChild(cropNode)

        timerBarBackground.fillColor = UIColor.white.withAlphaComponent(0.12)
        timerBarBackground.strokeColor = .clear
        addChild(timerBarBackground)
        // anchorPoint (0, 0.5) = il punto di aggancio è il bordo SINISTRO:
        // riducendo la larghezza la barra si accorcia verso sinistra.
        timerBarFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        addChild(timerBarFill)

        comboLabel.fontColor = .white
        comboLabel.verticalAlignmentMode = .center
        addChild(comboLabel)

        hintLabel.fontColor = UIColor.white.withAlphaComponent(0.6)
        hintLabel.verticalAlignmentMode = .center
        hintLabel.text = "Trascina un globo"
        addChild(hintLabel)

        for orb in board.allOrbs {
            let node = OrbNode(orb: orb, diameter: 1) // la vera misura arriva in layoutScene()
            orbNodes[orb.id] = node
            orbsLayer.addChild(node)
        }

        layoutScene()
        haptic.prepare()
    }

    /// Chiamato quando cambia la dimensione della scena (rotazione, foldable,
    /// Split View su iPad...). Grazie a `.resizeFill` basta ricalcolare il layout.
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard isSetUp else { return }
        layoutScene()
    }

    // MARK: - Layout adattivo

    private func layoutScene() {
        guard size.width > 0, size.height > 0 else { return }

        // Lato cella: il più grande possibile che faccia stare la griglia sia
        // in larghezza sia nel ~55% inferiore dello schermo. Il resto in alto
        // resta per timer e combo. `floor` evita mezzi pixel (bordi sfocati).
        let margin: CGFloat = 12
        let maxBoardWidth = size.width - margin * 2
        let maxBoardHeight = size.height * 0.55
        cellSize = floor(min(maxBoardWidth / CGFloat(board.cols),
                             maxBoardHeight / CGFloat(board.rows)))

        let boardWidth = cellSize * CGFloat(board.cols)
        // Centrata in orizzontale, ancorata in basso: il pollice ci arriva
        // tenendo il telefono con una mano sola.
        boardOrigin = CGPoint(x: ((size.width - boardWidth) / 2).rounded(), y: margin + 8)

        // Caselle a scacchiera (le ricreiamo: sono poche e cambiano misura).
        cellsLayer.removeAllChildren()
        let dark = UIColor(white: 1, alpha: 0.06)
        let light = UIColor(white: 1, alpha: 0.11)
        for row in 0..<board.rows {
            for col in 0..<board.cols {
                let tile = SKSpriteNode(color: (row + col).isMultiple(of: 2) ? dark : light,
                                        size: CGSize(width: cellSize, height: cellSize))
                tile.position = point(for: GridPosition(col: col, row: row))
                cellsLayer.addChild(tile)
            }
        }

        // Maschera del crop: solo ciò che sta dentro il rettangolo del tabellone
        // è visibile. Serve a nascondere i globi nuovi che "nascono" sopra la
        // griglia prima di cadere dentro.
        let mask = SKSpriteNode(color: .white, size: boardRect.size)
        mask.position = CGPoint(x: boardRect.midX, y: boardRect.midY)
        cropNode.maskNode = mask

        // Barra del timer, subito sopra la griglia e larga quanto la griglia.
        let barHeight: CGFloat = 14
        let barY = boardRect.maxY + 28
        timerBarBackground.path = UIBezierPath(
            roundedRect: CGRect(x: -boardWidth / 2, y: -barHeight / 2, width: boardWidth, height: barHeight),
            cornerRadius: barHeight / 2
        ).cgPath
        timerBarBackground.position = CGPoint(x: boardRect.midX, y: barY)
        timerBarFullWidth = boardWidth - 4
        timerBarFill.position = CGPoint(x: boardRect.minX + 2, y: barY)
        updateTimerBar()

        comboLabel.fontSize = max(24, cellSize * 0.5)
        comboLabel.position = CGPoint(x: boardRect.midX, y: barY + 50)
        hintLabel.fontSize = max(16, cellSize * 0.28)
        hintLabel.position = CGPoint(x: boardRect.midX, y: min(size.height - 30, barY + 110))

        // I globi si riposizionano solo se non c'è un'animazione in corso.
        if state == .resolvingMatches || state == .skyfall {
            needsOrbRelayout = true
        } else {
            layoutOrbs()
        }
    }

    private func layoutOrbs() {
        needsOrbRelayout = false
        let diameter = cellSize * orbSizeRatio
        for orb in board.allOrbs {
            guard let node = orbNodes[orb.id] else { continue }
            node.setDiameter(diameter)
            // Il globo trascinato segue il dito: non lo rimettiamo in cella.
            if node !== heldNode {
                node.removeAction(forKey: "move")
                node.position = point(for: orb.position)
            }
        }
    }

    // MARK: - Conversioni cella ↔ punto

    /// Centro della cella in coordinate scena (origine in basso a sinistra).
    /// Funziona anche con righe "virtuali" sopra la griglia (row >= rows).
    private func point(for position: GridPosition) -> CGPoint {
        CGPoint(x: boardOrigin.x + (CGFloat(position.col) + 0.5) * cellSize,
                y: boardOrigin.y + (CGFloat(position.row) + 0.5) * cellSize)
    }

    /// La cella che contiene il punto, o nil se il punto è fuori dalla griglia.
    private func gridPosition(at point: CGPoint) -> GridPosition? {
        guard cellSize > 0, boardRect.contains(point) else { return nil }
        let col = min(board.cols - 1, Int((point.x - boardOrigin.x) / cellSize))
        let row = min(board.rows - 1, Int((point.y - boardOrigin.y) / cellSize))
        return GridPosition(col: col, row: row)
    }

    /// Dove disegnare il globo trascinato: sopra il dito di `dragOffsetY`
    /// e "bloccato" dentro il tabellone (non può uscire dalla griglia).
    private func dragPoint(for touchLocation: CGPoint) -> CGPoint {
        let rect = boardRect.insetBy(dx: 1, dy: 1)
        return CGPoint(x: min(max(touchLocation.x, rect.minX), rect.maxX),
                       y: min(max(touchLocation.y + dragOffsetY, rect.minY), rect.maxY))
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Si può iniziare a trascinare solo da fermi e con un dito solo.
        guard state == .idle, activeTouch == nil, let touch = touches.first else { return }
        let location = touch.location(in: self)
        guard let position = gridPosition(at: location),
              let orb = board.orb(at: position),
              let node = orbNodes[orb.id] else { return }

        activeTouch = touch
        heldNode = node
        heldPosition = position
        timerStarted = false            // il timer NON parte al tocco...
        timeRemaining = turnDuration    // ...ma lo prepariamo pieno
        state = .dragging
        hintLabel.text = ""

        // Spostiamo il nodo fuori dal crop node e sopra a tutto: così il globo
        // sollevato non viene "tagliato" dai bordi del tabellone.
        // `move(toParent:)` mantiene la stessa posizione sullo schermo.
        node.move(toParent: self)
        node.zPosition = 100
        node.removeAction(forKey: "move")
        node.setLifted(true)
        node.position = dragPoint(for: location)

        haptic.prepare()
        updateTimerBar()
        print("[Scene] Preso globo \(orb.type.displayName) in \(position)")
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard state == .dragging,
              let touch = activeTouch, touches.contains(touch),
              let node = heldNode,
              var current = heldPosition else { return }

        let orbPoint = dragPoint(for: touch.location(in: self))
        node.position = orbPoint

        // Lo scambio avviene solo se il globo entra nella hitbox CIRCOLARE
        // al centro di una cella diversa da quella attuale.
        guard let target = gridPosition(at: orbPoint), target != current else { return }
        let center = point(for: target)
        let distance = hypot(orbPoint.x - center.x, orbPoint.y - center.y)
        guard distance <= cellSize * swapHitRadiusRatio else { return }

        // Se il dito è veloce può "saltare" più celle in un solo frame.
        // Invece di ignorarlo, ci arriviamo un passo alla volta (anche in
        // diagonale): è quello che il giocatore si aspetta di vedere.
        while current != target, state == .dragging {
            let next = GridPosition(col: current.col + (target.col - current.col).signum(),
                                    row: current.row + (target.row - current.row).signum())
            performSwap(from: current, to: next)
            current = next
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        endDrag(reason: "dito sollevato")
    }

    /// Il sistema può annullare un tocco (es. arriva una chiamata):
    /// lo trattiamo come un rilascio normale.
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        endDrag(reason: "tocco annullato")
    }

    // MARK: - Trascinamento

    private func performSwap(from: GridPosition, to: GridPosition) {
        guard let displaced = board.orb(at: to),
              let displacedNode = orbNodes[displaced.id],
              board.swap(from, to) else { return }

        // Solo il globo "spostato" si anima: quello trascinato segue già il dito.
        displacedNode.move(to: point(for: from), duration: 0.08)
        heldPosition = to

        haptic.impactOccurred()
        haptic.prepare()

        // REGOLA DEL TIMER: parte al primo scambio, non al tocco.
        // Così il giocatore può "pensare" tenendo il globo in mano.
        if !timerStarted {
            timerStarted = true
            timeRemaining = turnDuration
            print("[Scene] Primo scambio: parte il timer (\(turnDuration)s)")
        }
    }

    private func endDrag(reason: String) {
        guard state == .dragging, let node = heldNode, let position = heldPosition else { return }
        print("[Scene] Fine trascinamento: \(reason)")

        let didSwap = timerStarted
        activeTouch = nil
        heldNode = nil
        heldPosition = nil
        timerStarted = false

        // Rimettiamo il globo nel tabellone, nella sua (nuova) cella.
        node.move(toParent: orbsLayer)
        node.zPosition = 0
        node.setLifted(false)
        node.move(to: point(for: position), duration: 0.1)

        // Nessuno scambio = nessuna mossa: torniamo in attesa.
        guard didSwap else {
            state = .idle
            hintLabel.text = "Trascina un globo"
            updateTimerBar()
            return
        }

        comboCount = 0
        updateComboLabel()
        state = .resolvingMatches
        updateTimerBar()
        // Piccola attesa per lasciare che il globo si "appoggi" nella cella.
        run(.wait(forDuration: 0.12)) { [weak self] in
            self?.resolveMatches()
        }
    }

    // MARK: - Game loop (timer)

    /// SpriteKit chiama `update` una volta per frame (60 o 120 volte al secondo).
    /// `currentTime` è un orologio assoluto: il tempo passato dall'ultimo frame
    /// (delta time) è la differenza con il valore precedente.
    override func update(_ currentTime: TimeInterval) {
        defer { lastUpdateTime = currentTime }
        guard let last = lastUpdateTime else { return }
        // Limitiamo il delta: se l'app torna dal background il primo delta
        // sarebbe enorme e il timer scadrebbe istantaneamente.
        let dt = min(currentTime - last, 1.0 / 15.0)

        guard state == .dragging, timerStarted else { return }
        timeRemaining -= dt
        updateTimerBar()
        if timeRemaining <= 0 {
            endDrag(reason: "tempo scaduto")
        }
    }

    private func updateTimerBar() {
        let running = state == .dragging && timerStarted
        let fraction = running ? max(0, timeRemaining / turnDuration) : 1
        timerBarFill.size = CGSize(width: timerBarFullWidth * CGFloat(fraction),
                                   height: 10)
        // Verde → giallo → rosso: si capisce l'urgenza senza leggere numeri.
        timerBarFill.color = fraction < 0.3 ? .systemRed : (fraction < 0.6 ? .systemYellow : .systemGreen)
        // Barra "spenta" quando il timer non sta correndo.
        timerBarFill.alpha = running ? 1 : 0.35
    }

    // MARK: - Risoluzione combo

    /// Punto d'ingresso del loop a cascata:
    /// resolvingMatches → skyfall → resolvingMatches → ... → idle.
    private func resolveMatches() {
        state = .resolvingMatches
        let combos = board.findCombos()
        guard !combos.isEmpty else {
            finishTurn()
            return
        }
        removeCombo(at: 0, in: combos)
    }

    /// Rimuove UNA combo, aspetta un attimo, poi passa alla successiva.
    /// È una funzione "ricorsiva nel tempo": invece di un ciclo for (che
    /// rimuoverebbe tutto nello stesso frame) si richiama dopo un'attesa.
    private func removeCombo(at index: Int, in combos: [Combo]) {
        guard index < combos.count else {
            startSkyfall()
            return
        }

        let combo = combos[index]
        comboCount += 1
        updateComboLabel()

        // Prima calcoliamo il centro del gruppo (per il testo fluttuante)...
        var sum = CGPoint.zero
        for orb in combo.orbs {
            let p = point(for: orb.position)
            sum.x += p.x
            sum.y += p.y
        }
        let center = CGPoint(x: sum.x / CGFloat(combo.orbs.count),
                             y: sum.y / CGFloat(combo.orbs.count))

        // ...poi togliamo i globi dal modello e facciamo esplodere i nodi.
        board.remove(combo.orbs)
        for orb in combo.orbs {
            orbNodes.removeValue(forKey: orb.id)?.explode()
        }

        showFloatingText("Combo \(comboCount)!", at: center, color: combo.type.color)

        run(.wait(forDuration: comboStepDuration)) { [weak self] in
            self?.removeCombo(at: index + 1, in: combos)
        }
    }

    // MARK: - Skyfall

    private func startSkyfall() {
        state = .skyfall
        let drops = board.applyGravityAndRefill()
        let diameter = cellSize * orbSizeRatio
        var longest: TimeInterval = 0

        for drop in drops {
            let node: OrbNode
            if drop.isNew {
                // Nasce sopra la griglia (nascosto dal crop) e poi cade dentro.
                node = OrbNode(orb: drop.orb, diameter: diameter)
                node.position = point(for: drop.from)
                orbsLayer.addChild(node)
                orbNodes[drop.orb.id] = node
            } else {
                guard let existing = orbNodes[drop.orb.id] else { continue }
                node = existing
            }
            // Più celle deve percorrere, più dura la caduta.
            let cells = Double(drop.from.row - drop.to.row)
            let duration = 0.12 + 0.05 * cells
            node.fall(to: point(for: drop.to), duration: duration)
            longest = max(longest, duration)
        }

        // Quando l'ultima caduta è finita, ricontrolliamo: i nuovi globi
        // potrebbero aver creato altri match (cascata).
        run(.wait(forDuration: longest + 0.05)) { [weak self] in
            self?.resolveMatches()
        }
    }

    private func finishTurn() {
        print("[Scene] Turno concluso: \(comboCount) combo totali")
        state = .idle
        hintLabel.text = comboCount == 0 ? "Nessuna combo, riprova!" : ""
        if needsOrbRelayout { layoutOrbs() }
        updateTimerBar()
    }

    // MARK: - Feedback visivo

    private func updateComboLabel() {
        comboLabel.text = comboCount > 0 ? "\(comboCount) Combo" : ""
        guard comboCount > 0 else { return }
        // Piccolo "pop" a ogni combo in più.
        comboLabel.removeAllActions()
        comboLabel.setScale(1.25)
        comboLabel.run(.scale(to: 1.0, duration: 0.15))
    }

    /// Testo che sale e svanisce sopra il gruppo appena rimosso.
    private func showFloatingText(_ text: String, at position: CGPoint, color: UIColor) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = max(18, cellSize * 0.4)
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.position = position
        label.zPosition = 200
        addChild(label)

        let rise = SKAction.moveBy(x: 0, y: cellSize * 0.8, duration: 0.6)
        let fade = SKAction.sequence([.wait(forDuration: 0.3), .fadeOut(withDuration: 0.3)])
        label.run(.sequence([.group([rise, fade]), .removeFromParent()]))
    }
}
