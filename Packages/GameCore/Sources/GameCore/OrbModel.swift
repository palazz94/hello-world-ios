//  OrbModel.swift
//  GameCore
//
//  Questo file contiene SOLO dati: nessuna grafica, nessun touch.
//  Vive nel package GameCore (separato dall'app) proprio per forzare la
//  separazione Model / View: il compilatore impedisce a questo codice di
//  usare SpriteKit, quindi la logica resta pura e testabile anche su Linux.

import Foundation

// UIKit esiste solo su iOS. Con `#if canImport(UIKit)` il package compila
// anche dove UIKit non c'è (es. `swift build` / `swift test` su Linux):
// in quel caso la proprietà `color` semplicemente non viene inclusa.
#if canImport(UIKit)
import UIKit
#endif

// MARK: - OrbType

/// I 6 tipi di globo, come in Puzzle & Dragons.
///
/// È un `enum` perché i tipi sono un insieme chiuso e noto a priori:
/// il compilatore ci obbliga a gestire tutti i casi in ogni `switch`,
/// così se un giorno aggiungiamo un tipo non dimentichiamo nessun punto.
/// `CaseIterable` ci regala `OrbType.allCases`, comodo per scegliere un tipo a caso.
public enum OrbType: Int, CaseIterable, Sendable {
    case fire    // Fuoco   - rosso
    case water   // Acqua   - blu
    case wood    // Legno   - verde
    case light   // Luce    - giallo
    case dark    // Oscurità - viola
    case heart   // Cuore   - rosa

    /// Nome leggibile, usato nei log di debug.
    public var displayName: String {
        switch self {
        case .fire: return "Fuoco"
        case .water: return "Acqua"
        case .wood: return "Legno"
        case .light: return "Luce"
        case .dark: return "Oscurità"
        case .heart: return "Cuore"
        }
    }

    /// Una lettera per stampare la griglia in console in modo compatto.
    public var debugLetter: Character {
        switch self {
        case .fire: return "R"
        case .water: return "B"
        case .wood: return "G"
        case .light: return "Y"
        case .dark: return "P"
        case .heart: return "H"
        }
    }

    /// Simbolo disegnato dentro al globo: chi è daltonico distingue i tipi
    /// dalla forma e non solo dal colore. Sono caratteri Unicode standard,
    /// quindi non servono immagini esterne.
    public var symbol: String {
        switch self {
        case .fire: return "▲"
        case .water: return "●"
        case .wood: return "♣"
        case .light: return "★"
        case .dark: return "◆"
        case .heart: return "♥"
        }
    }

    #if canImport(UIKit)
    /// Colore del globo. `UIColor` è il tipo colore di UIKit che SpriteKit accetta direttamente.
    public var color: UIColor {
        switch self {
        case .fire: return UIColor(red: 0.93, green: 0.26, blue: 0.21, alpha: 1)
        case .water: return UIColor(red: 0.20, green: 0.52, blue: 0.95, alpha: 1)
        case .wood: return UIColor(red: 0.25, green: 0.75, blue: 0.33, alpha: 1)
        case .light: return UIColor(red: 0.98, green: 0.80, blue: 0.18, alpha: 1)
        case .dark: return UIColor(red: 0.60, green: 0.30, blue: 0.85, alpha: 1)
        case .heart: return UIColor(red: 0.98, green: 0.45, blue: 0.70, alpha: 1)
        }
    }
    #endif
}

// MARK: - GridPosition

/// Coordinata di una cella nella griglia.
///
/// Convenzione: `row = 0` è la riga IN BASSO, come l'asse Y di SpriteKit
/// (che cresce verso l'alto). Così "cadere" significa "diminuire row"
/// e la conversione cella → punto sullo schermo è una semplice moltiplicazione.
///
/// È una `struct` (tipo valore): due posizioni con stessi col/row sono
/// identiche, e copiarla non crea riferimenti condivisi.
/// `Hashable` permette di usarla come chiave di dizionari / elementi di Set.
public struct GridPosition: Hashable, Sendable, CustomStringConvertible {
    public let col: Int
    public let row: Int

    public init(col: Int, row: Int) {
        self.col = col
        self.row = row
    }

    /// Vero se `other` è una delle 8 celle attorno a questa (diagonali comprese).
    /// Usiamo la "distanza di Chebyshev": max(|dx|, |dy|) == 1.
    public func isAdjacent(to other: GridPosition) -> Bool {
        let dc = abs(col - other.col)
        let dr = abs(row - other.row)
        return max(dc, dr) == 1
    }

    /// Le 4 celle vicine in orizzontale/verticale (senza diagonali).
    /// Servono al flood-fill: i match si collegano solo ortogonalmente.
    /// Nota: possono uscire dalla griglia, chi le usa deve controllarle.
    public var orthogonalNeighbors: [GridPosition] {
        [
            GridPosition(col: col + 1, row: row),
            GridPosition(col: col - 1, row: row),
            GridPosition(col: col, row: row + 1),
            GridPosition(col: col, row: row - 1),
        ]
    }

    public var description: String { "(c\(col),r\(row))" }
}

// MARK: - Orb

/// Un singolo globo sul tabellone.
///
/// È una `class` (tipo riferimento) e non una struct perché il globo ha
/// un'IDENTITÀ: quando si sposta resta "lo stesso" globo. La scena usa `id`
/// per ritrovare il suo nodo grafico (OrbNode) e animarlo, invece di
/// distruggere e ricreare la grafica a ogni spostamento.
public final class Orb: Identifiable {
    /// Identificatore univoco, generato alla nascita e mai più cambiato.
    public let id = UUID()
    /// Il tipo non cambia mai: un globo di fuoco resta di fuoco.
    public let type: OrbType
    /// La posizione invece cambia (scambi, gravità). La aggiorna solo BoardLogic.
    public internal(set) var position: GridPosition

    public init(type: OrbType, position: GridPosition) {
        self.type = type
        self.position = position
    }
}
