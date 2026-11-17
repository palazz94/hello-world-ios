//  BoardLogic.swift
//  GameCore
//
//  Tutta la "matematica" del tabellone 6x5: generazione, scambi, ricerca
//  delle combo, gravità e skyfall. Nessuna animazione e nessun touch:
//  la scena chiede a questa classe COSA è successo e poi decide COME mostrarlo.
//  Vantaggio: possiamo testare le regole del gioco senza avviare la grafica.

import Foundation

// MARK: - Tipi di risultato

/// Una combo = un gruppo di globi dello stesso tipo che spariscono insieme.
public struct Combo {
    public let type: OrbType
    public let orbs: [Orb]
}

/// Descrive lo spostamento di un globo durante lo skyfall.
/// La scena lo usa per animare il nodo da `from` a `to`.
public struct OrbDrop {
    public let orb: Orb
    /// Da dove parte. Per i globi nuovi è una riga "virtuale" sopra la griglia
    /// (row >= rows), così l'animazione li fa entrare dall'alto.
    public let from: GridPosition
    public let to: GridPosition
    /// true se il globo è appena stato generato (la scena deve creare il nodo).
    public let isNew: Bool
}

// MARK: - BoardLogic

/// Il tabellone. È una `final class`: una sola istanza condivisa e modificata
/// nel tempo dalla scena (se fosse una struct ogni assegnazione la copierebbe).
public final class BoardLogic {
    public let cols: Int
    public let rows: Int

    /// La matrice vera e propria: `grid[row][col]`.
    /// `Orb?` (opzionale) perché dopo un match la cella resta vuota (`nil`)
    /// finché la gravità non la riempie.
    private var grid: [[Orb?]]

    /// Crea un tabellone casuale senza match iniziali.
    public init(cols: Int = 6, rows: Int = 5) {
        self.cols = cols
        self.rows = rows
        self.grid = Array(repeating: Array(repeating: nil, count: cols), count: rows)
        generateInitialBoard()
    }

    /// Crea un tabellone con una disposizione precisa (utile nei test).
    /// `types` va scritto "come si vede": il primo array è la riga IN ALTO.
    init(types: [[OrbType]]) {
        self.rows = types.count
        self.cols = types.first?.count ?? 0
        self.grid = Array(repeating: Array(repeating: nil, count: cols), count: rows)
        for (visualRow, line) in types.enumerated() {
            let row = rows - 1 - visualRow // la riga visuale 0 è quella più in alto
            for (col, type) in line.enumerated() {
                grid[row][col] = Orb(type: type, position: GridPosition(col: col, row: row))
            }
        }
    }

    // MARK: Accesso

    /// Il globo in una cella, o `nil` se la cella è vuota o fuori griglia.
    public func orb(at position: GridPosition) -> Orb? {
        guard isInside(position) else { return nil }
        return grid[position.row][position.col]
    }

    /// Tutti i globi presenti (comodo per creare/riposizionare i nodi grafici).
    public var allOrbs: [Orb] {
        grid.flatMap { $0 }.compactMap { $0 }
    }

    public func isInside(_ p: GridPosition) -> Bool {
        p.col >= 0 && p.col < cols && p.row >= 0 && p.row < rows
    }

    // MARK: Generazione iniziale

    /// Riempie la griglia cella per cella (dal basso a sinistra) scegliendo
    /// per ogni cella un tipo che NON crei un tris.
    ///
    /// Perché funziona: riempiendo in ordine, quando siamo sulla cella (col,row)
    /// sono già piene solo quelle a sinistra e quelle sotto. Un tris nuovo può
    /// nascere solo se le 2 celle a sinistra o le 2 sotto hanno lo stesso tipo:
    /// basta escludere quel tipo. Si escludono al massimo 2 tipi su 6, quindi
    /// c'è sempre una scelta valida e non serve rigenerare a tentativi.
    public func generateInitialBoard() {
        for row in 0..<rows {
            for col in 0..<cols {
                var candidates = Set(OrbType.allCases)

                if col >= 2,
                   let left1 = grid[row][col - 1]?.type,
                   left1 == grid[row][col - 2]?.type {
                    candidates.remove(left1)
                }
                if row >= 2,
                   let below1 = grid[row - 1][col]?.type,
                   below1 == grid[row - 2][col]?.type {
                    candidates.remove(below1)
                }

                // `!` è sicuro: restano sempre almeno 4 candidati su 6.
                let type = candidates.randomElement()!
                grid[row][col] = Orb(type: type, position: GridPosition(col: col, row: row))
            }
        }
        print("[Board] Griglia iniziale generata (\(cols)x\(rows)), match presenti: \(findCombos(log: false).count)")
        debugPrintBoard()
    }

    // MARK: Scambio

    /// Scambia i globi di due celle adiacenti (diagonali comprese).
    /// Restituisce `false` se lo scambio non è valido.
    @discardableResult
    public func swap(_ a: GridPosition, _ b: GridPosition) -> Bool {
        guard isInside(a), isInside(b), a.isAdjacent(to: b) else {
            print("[Board] Scambio rifiutato \(a) <-> \(b)")
            return false
        }
        let orbA = grid[a.row][a.col]
        let orbB = grid[b.row][b.col]
        grid[a.row][a.col] = orbB
        grid[b.row][b.col] = orbA
        // Il modello è l'unica "fonte di verità": aggiorniamo anche la
        // posizione salvata dentro ogni Orb, così resta coerente con la matrice.
        orbA?.position = b
        orbB?.position = a
        print("[Board] Scambio \(a) <-> \(b)")
        return true
    }

    // MARK: Ricerca combo

    /// Trova tutte le combo presenti, con le regole di Puzzle & Dragons:
    ///
    /// 1. Un globo "conta" solo se fa parte di una fila orizzontale o verticale
    ///    di 3+ globi uguali. (Un semplice gruppo a "L" di 3 globi NON è un match.)
    /// 2. I globi marcati dello stesso tipo che si toccano ortogonalmente
    ///    formano UNA sola combo (es. una croce o una "T" valgono 1 combo).
    ///    Per raggrupparli usiamo un flood-fill in ampiezza (BFS).
    public func findCombos() -> [Combo] {
        findCombos(log: true)
    }

    private func findCombos(log: Bool) -> [Combo] {
        // Passo 1: matrice di booleani "questa cella fa parte di un tris?"
        var matched = Array(repeating: Array(repeating: false, count: cols), count: rows)

        // Scansione orizzontale: per ogni riga cerchiamo "run" di tipi uguali.
        for row in 0..<rows {
            var start = 0
            while start < cols {
                guard let type = grid[row][start]?.type else { start += 1; continue }
                var end = start + 1
                while end < cols, grid[row][end]?.type == type { end += 1 }
                if end - start >= 3 {
                    for c in start..<end { matched[row][c] = true }
                }
                start = end // saltiamo direttamente alla fine del run
            }
        }

        // Scansione verticale: stessa idea, colonna per colonna.
        for col in 0..<cols {
            var start = 0
            while start < rows {
                guard let type = grid[start][col]?.type else { start += 1; continue }
                var end = start + 1
                while end < rows, grid[end][col]?.type == type { end += 1 }
                if end - start >= 3 {
                    for r in start..<end { matched[r][col] = true }
                }
                start = end
            }
        }

        // Passo 2: flood-fill (BFS) per unire le celle marcate in gruppi connessi.
        var visited = Array(repeating: Array(repeating: false, count: cols), count: rows)
        var combos: [Combo] = []

        for row in 0..<rows {
            for col in 0..<cols {
                guard matched[row][col], !visited[row][col], let seed = grid[row][col] else { continue }

                // BFS: una "coda" di celle da esplorare. Usiamo un array + indice
                // invece di removeFirst() perché removeFirst() sposta tutti gli
                // elementi (lento); l'indice invece avanza e basta.
                var queue = [GridPosition(col: col, row: row)]
                var index = 0
                visited[row][col] = true
                var members: [Orb] = []

                while index < queue.count {
                    let current = queue[index]
                    index += 1
                    if let orb = grid[current.row][current.col] { members.append(orb) }

                    for next in current.orthogonalNeighbors where isInside(next) {
                        guard matched[next.row][next.col],
                              !visited[next.row][next.col],
                              grid[next.row][next.col]?.type == seed.type else { continue }
                        visited[next.row][next.col] = true
                        queue.append(next)
                    }
                }
                combos.append(Combo(type: seed.type, orbs: members))
            }
        }

        if log {
            print("[Board] Combo trovate: \(combos.count)")
            for (i, combo) in combos.enumerated() {
                print("        #\(i + 1) \(combo.type.displayName) x\(combo.orbs.count)")
            }
        }
        return combos
    }

    // MARK: Rimozione

    /// Svuota le celle dei globi indicati (la cella diventa `nil`).
    public func remove(_ orbs: [Orb]) {
        for orb in orbs {
            let p = orb.position
            // `===` confronta l'identità (stesso oggetto), non il contenuto:
            // svuotiamo la cella solo se contiene davvero QUEL globo.
            if isInside(p), grid[p.row][p.col] === orb {
                grid[p.row][p.col] = nil
            }
        }
        print("[Board] Rimossi \(orbs.count) globi")
    }

    // MARK: Gravità + Skyfall

    /// 1. Fa "cadere" i globi verso il basso per chiudere i buchi.
    /// 2. Riempie le celle rimaste vuote in alto con globi nuovi casuali.
    ///
    /// Restituisce l'elenco degli spostamenti così la scena può animarli.
    /// Nota: i globi nuovi sono casuali senza filtro, quindi possono creare
    /// nuovi match: è proprio la cascata ("skyfall combo") che vogliamo.
    public func applyGravityAndRefill() -> [OrbDrop] {
        var drops: [OrbDrop] = []

        for col in 0..<cols {
            // `writeRow` = prossima cella libera dal basso. Scorriamo la colonna
            // dal basso verso l'alto e "compattiamo" i globi verso il fondo.
            var writeRow = 0
            for row in 0..<rows {
                guard let orb = grid[row][col] else { continue }
                if row != writeRow {
                    grid[writeRow][col] = orb
                    grid[row][col] = nil
                    let from = orb.position
                    orb.position = GridPosition(col: col, row: writeRow)
                    drops.append(OrbDrop(orb: orb, from: from, to: orb.position, isNew: false))
                }
                writeRow += 1
            }

            // Dalle `writeRow` in su la colonna è vuota: generiamo globi nuovi.
            // Il primo nuovo parte dalla riga virtuale `rows` (appena sopra la
            // griglia), il secondo da `rows + 1`, ecc.: così cadono in fila.
            var spawnIndex = 0
            for row in writeRow..<rows {
                let target = GridPosition(col: col, row: row)
                let orb = Orb(type: OrbType.allCases.randomElement()!, position: target)
                grid[row][col] = orb
                let from = GridPosition(col: col, row: rows + spawnIndex)
                drops.append(OrbDrop(orb: orb, from: from, to: target, isNew: true))
                spawnIndex += 1
            }
        }

        let spawned = drops.filter(\.isNew).count
        print("[Board] Skyfall: \(drops.count - spawned) globi caduti, \(spawned) nuovi")
        debugPrintBoard()
        return drops
    }

    // MARK: Debug

    /// Stampa la griglia in console, riga più alta in cima (come sullo schermo).
    public func debugPrintBoard() {
        for row in stride(from: rows - 1, through: 0, by: -1) {
            let line = (0..<cols).map { col in
                grid[row][col].map { String($0.type.debugLetter) } ?? "."
            }
            print("        " + line.joined(separator: " "))
        }
    }
}
