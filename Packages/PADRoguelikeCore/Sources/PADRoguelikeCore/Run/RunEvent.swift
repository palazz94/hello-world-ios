import Foundation

public enum EventEffect: Hashable, Codable, Sendable {
    /// Fraction of max HP; never lethal.
    case loseHP(Double)
    case heal(Double)
    case gainGold(Int)
    case loseGold(Int)
    /// A random unowned relic of at least this rarity.
    case gainRelic(Rarity)
    case levelUp
    /// Starts a fight (`.combat` or `.elite`); later effects of the option are ignored.
    case fight(NodeKind)
}

public struct EventOption: Hashable, Codable, Sendable {
    public let label: String
    public let effects: [EventEffect]

    public init(_ label: String, _ effects: [EventEffect] = []) {
        self.label = label
        self.effects = effects
    }

    public var goldCost: Int {
        effects.reduce(0) { total, effect in
            if case let .loseGold(amount) = effect { total + amount } else { total }
        }
    }
}

/// Text room with a choice, usually trading HP, gold or safety for power.
public struct RunEvent: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let text: String
    public let options: [EventOption]

    public init(id: String, title: String, text: String, options: [EventOption]) {
        self.id = id
        self.title = title
        self.text = text
        self.options = options
    }
}

public extension RunEvent {
    static let standard: [RunEvent] = [
        RunEvent(id: "blood-altar", title: "Altare di Sangue",
                 text: "Una pietra nera pulsa nel buio. Una voce sussurra: \"Il potere ha un prezzo.\"",
                 options: [
                     EventOption("Offri il tuo sangue (-25% HP): reliquia rara", [.loseHP(0.25), .gainRelic(.rare)]),
                     EventOption("Allontanati"),
                 ]),
        RunEvent(id: "fountain", title: "Fontana Antica",
                 text: "L'acqua è limpida e luccica di magia. Sul fondo, monete di avventurieri passati.",
                 options: [
                     EventOption("Bevi (+40% HP)", [.heal(0.4)]),
                     EventOption("Getta 40 oro ed esprimi un desiderio: +1 livello", [.loseGold(40), .levelUp]),
                 ]),
        RunEvent(id: "gambler", title: "Il Giocatore",
                 text: "Un uomo con un sorriso storto mescola le carte. \"Una partita, straniero?\"",
                 options: [
                     EventOption("Paga 60 oro: reliquia rara", [.loseGold(60), .gainRelic(.rare)]),
                     EventOption("Sfidalo a duello: +40 oro, poi combatti", [.gainGold(40), .fight(.combat)]),
                     EventOption("Rifiuta"),
                 ]),
        RunEvent(id: "wounded-knight", title: "Cavaliere Ferito",
                 text: "Un cavaliere giace contro un albero, l'armatura squarciata. Accanto a lui, una borsa piena.",
                 options: [
                     EventOption("Curalo (-15% HP): ti insegna una tecnica, +1 livello", [.loseHP(0.15), .levelUp]),
                     EventOption("Prendi la borsa (+90 oro): si rialza e ti attacca", [.gainGold(90), .fight(.elite)]),
                     EventOption("Lascialo in pace"),
                 ]),
        RunEvent(id: "glowing-mushrooms", title: "Funghi Luminosi",
                 text: "Un cerchio di funghi brilla di luce viola. L'aria sa di miele e di guai.",
                 options: [
                     EventOption("Mangiane uno (-20% HP): +1 livello", [.loseHP(0.2), .levelUp]),
                     EventOption("Raccoglili e vendili: +35 oro", [.gainGold(35)]),
                 ]),
        RunEvent(id: "suspicious-chest", title: "Forziere Sospetto",
                 text: "Un forziere dorato, troppo bello per essere vero, in mezzo al corridoio.",
                 options: [
                     EventOption("Aprilo: reliquia, ma scatta una trappola (-20% HP)", [.gainRelic(.common), .loseHP(0.2)]),
                     EventOption("Non fidarti"),
                 ]),
        RunEvent(id: "light-shrine", title: "Santuario della Luce",
                 text: "Un santuario sigillato. Dietro il sigillo qualcosa di antico si muove.",
                 options: [
                     EventOption("Prega (+25% HP)", [.heal(0.25)]),
                     EventOption("Spezza il sigillo: reliquia leggendaria, ma il guardiano si sveglia",
                                 [.gainRelic(.legendary), .fight(.elite)]),
                 ]),
        RunEvent(id: "ghost-merchant", title: "Mercante Fantasma",
                 text: "Una figura trasparente apre un mantello pieno di ninnoli. \"Accetto oro... o sangue.\"",
                 options: [
                     EventOption("Vendi sangue (-30% HP): +100 oro", [.loseHP(0.3), .gainGold(100)]),
                     EventOption("Compra un amuleto (75 oro): reliquia rara", [.loseGold(75), .gainRelic(.rare)]),
                     EventOption("Vai via"),
                 ]),
    ]
}
