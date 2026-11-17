//  OrbNode.swift
//  HelloWorld
//
//  La rappresentazione GRAFICA di un globo. Non conosce le regole del gioco:
//  sa solo disegnarsi e animarsi. Il collegamento con il modello è `orbID`,
//  che corrisponde a `Orb.id` in GameCore.

import SpriteKit
import UIKit
import GameCore

/// Un globo disegnato con forme vettoriali (nessuna immagine PNG).
///
/// Estende `SKNode` (il "contenitore" base di SpriteKit) invece di
/// `SKShapeNode` perché un globo è composto da più pezzi: corpo, riflesso
/// e simbolo. Raggruppandoli in un nodo padre, spostando/scalando il padre
/// si muovono tutti insieme.
final class OrbNode: SKNode {
    /// Lo stesso id dell'`Orb` nel modello: è il "ponte" tra Model e View.
    let orbID: UUID
    let type: OrbType
    private(set) var diameter: CGFloat = 0

    // Chiavi delle animazioni: lanciando una nuova animazione con la stessa
    // chiave, SpriteKit interrompe la precedente. Evita conflitti tipo due
    // "move" contemporanei che tirano il nodo in direzioni diverse.
    private enum ActionKey {
        static let move = "move"
        static let lift = "lift"
    }

    init(orb: Orb, diameter: CGFloat) {
        self.orbID = orb.id
        self.type = orb.type
        super.init()
        setDiameter(diameter)
    }

    // Obbligatorio per le sottoclassi di SKNode (serve per caricare nodi da
    // file .sks). Noi creiamo tutto da codice, quindi non lo supportiamo.
    required init?(coder aDecoder: NSCoder) {
        fatalError("OrbNode viene creato solo da codice")
    }

    // MARK: Disegno

    /// (Ri)disegna il globo alla dimensione indicata. Viene richiamato anche
    /// quando lo schermo cambia dimensione (es. apertura di un foldable).
    func setDiameter(_ newDiameter: CGFloat) {
        guard newDiameter != diameter, newDiameter > 0 else { return }
        diameter = newDiameter
        removeAllChildren()

        let radius = newDiameter / 2

        // Corpo: cerchio pieno del colore del tipo, con bordo chiaro.
        let body = SKShapeNode(circleOfRadius: radius)
        body.fillColor = type.color
        body.strokeColor = UIColor.white.withAlphaComponent(0.85)
        body.lineWidth = max(1.5, newDiameter * 0.04)
        addChild(body)

        // Riflesso: piccolo cerchio bianco semitrasparente in alto a sinistra.
        // È un trucco economico per dare l'idea di una sfera "lucida".
        let shine = SKShapeNode(circleOfRadius: radius * 0.32)
        shine.fillColor = UIColor.white.withAlphaComponent(0.35)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: -radius * 0.32, y: radius * 0.32)
        addChild(shine)

        // Simbolo per l'accessibilità (daltonici): forma diversa per ogni tipo.
        let label = SKLabelNode(text: type.symbol)
        label.fontName = "HelveticaNeue-Bold"
        label.fontSize = newDiameter * 0.42
        label.fontColor = UIColor.white.withAlphaComponent(0.9)
        // Di default il testo è appoggiato sulla "linea di base": centrando
        // verticalmente il simbolo finisce esattamente al centro del cerchio.
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        addChild(label)
    }

    // MARK: Animazioni

    /// Effetto "sollevato" mentre il dito lo trascina: più grande e un po' trasparente
    /// (così si intravede il globo sotto).
    func setLifted(_ lifted: Bool) {
        let scale = SKAction.scale(to: lifted ? 1.18 : 1.0, duration: 0.08)
        let fade = SKAction.fadeAlpha(to: lifted ? 0.85 : 1.0, duration: 0.08)
        run(.group([scale, fade]), withKey: ActionKey.lift)
    }

    /// Spostamento breve e fluido (scambi, ritorno in cella).
    /// `easeOut` = parte veloce e rallenta: dà una sensazione "reattiva".
    func move(to point: CGPoint, duration: TimeInterval) {
        let action = SKAction.move(to: point, duration: duration)
        action.timingMode = .easeOut
        run(action, withKey: ActionKey.move)
    }

    /// Caduta per lo skyfall. `easeIn` = parte lento e accelera, come la gravità.
    func fall(to point: CGPoint, duration: TimeInterval) {
        let action = SKAction.move(to: point, duration: duration)
        action.timingMode = .easeIn
        run(action, withKey: ActionKey.move)
    }

    /// Esplosione quando fa parte di una combo: si gonfia, sparisce e si
    /// rimuove dalla scena (così non resta in memoria).
    func explode() {
        removeAllActions()
        let pop = SKAction.group([
            .scale(to: 1.35, duration: 0.18),
            .fadeOut(withDuration: 0.18),
        ])
        run(.sequence([pop, .removeFromParent()]))
    }
}
