import Foundation

// Readable JSON for content files and saves:
// - things that act (modifiers, ability effects, event effects) are objects with a "type" field;
// - conditions and enemy traits are objects with a single key, e.g. {"orbsExactly": 4};
// - orb types, elements and rarities are written by name.
// Unknown fields are rejected so typos in data files fail loudly.

struct AnyKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }

    init(_ stringValue: String) { self.stringValue = stringValue }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

extension KeyedDecodingContainer where Key == AnyKey {
    func value<T: Decodable>(_ key: String) throws -> T { try decode(T.self, forKey: AnyKey(key)) }
    func optional<T: Decodable>(_ key: String) throws -> T? { try decodeIfPresent(T.self, forKey: AnyKey(key)) }

    func allowOnly(_ keys: Set<String>) throws {
        if let unknown = allKeys.map(\.stringValue).sorted().first(where: { !keys.contains($0) }) {
            throw DecodingError.dataCorruptedError(forKey: AnyKey(unknown), in: self,
                                                   debugDescription: "Unknown field \"\(unknown)\"; expected one of \(keys.sorted())")
        }
    }

    /// For single-key objects such as conditions and traits.
    func onlyKey() throws -> String {
        guard allKeys.count == 1, let key = allKeys.first?.stringValue else {
            throw DecodingError.dataCorrupted(.init(codingPath: codingPath,
                                                    debugDescription: "Expected an object with exactly one key, found \(allKeys.map(\.stringValue).sorted())"))
        }
        return key
    }

    func unknown(_ kind: String, _ name: String, key: String) -> DecodingError {
        .dataCorruptedError(forKey: AnyKey(key), in: self, debugDescription: "Unknown \(kind) \"\(name)\"")
    }
}

extension KeyedEncodingContainer where Key == AnyKey {
    mutating func put<T: Encodable>(_ value: T, _ key: String) throws { try encode(value, forKey: AnyKey(key)) }
    mutating func putIfPresent<T: Encodable>(_ value: T?, _ key: String) throws { try encodeIfPresent(value, forKey: AnyKey(key)) }
}

// MARK: - Names

extension OrbType {
    public var name: String {
        switch self {
        case .fire: "fire"
        case .water: "water"
        case .wood: "wood"
        case .light: "light"
        case .dark: "dark"
        case .heal: "heal"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let name = try container.decode(String.self)
        guard let type = OrbType.allCases.first(where: { $0.name == name }) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown orb type \"\(name)\"")
        }
        self = type
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(name)
    }
}

extension Rarity {
    public var name: String {
        switch self {
        case .common: "common"
        case .rare: "rare"
        case .legendary: "legendary"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let name = try container.decode(String.self)
        guard let rarity = [Rarity.common, .rare, .legendary].first(where: { $0.name == name }) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown rarity \"\(name)\"")
        }
        self = rarity
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(name)
    }
}

// MARK: - Conditions and traits

extension ClusterCondition {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        let key = try c.onlyKey()
        switch key {
        case "orbsAtLeast": self = .orbsAtLeast(try c.value(key))
        case "orbsAtMost": self = .orbsAtMost(try c.value(key))
        case "orbsExactly": self = .orbsExactly(try c.value(key))
        default: throw c.unknown("match condition", key, key: key)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        switch self {
        case let .orbsAtLeast(count): try c.put(count, "orbsAtLeast")
        case let .orbsAtMost(count): try c.put(count, "orbsAtMost")
        case let .orbsExactly(count): try c.put(count, "orbsExactly")
        }
    }
}

extension TurnCondition {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        let key = try c.onlyKey()
        switch key {
        case "combosAtLeast": self = .combosAtLeast(try c.value(key))
        case "combosAtMost": self = .combosAtMost(try c.value(key))
        case "colorsAtLeast": self = .colorsAtLeast(try c.value(key))
        case "matched": self = .matched(try c.value(key))
        case "orbsAtLeast": self = .orbsAtLeast(try c.value(key))
        case "hpBelow": self = .hpBelow(try c.value(key))
        case "hpAbove": self = .hpAbove(try c.value(key))
        default: throw c.unknown("move condition", key, key: key)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        switch self {
        case let .combosAtLeast(count): try c.put(count, "combosAtLeast")
        case let .combosAtMost(count): try c.put(count, "combosAtMost")
        case let .colorsAtLeast(count): try c.put(count, "colorsAtLeast")
        case let .matched(types): try c.put(types, "matched")
        case let .orbsAtLeast(count): try c.put(count, "orbsAtLeast")
        case let .hpBelow(fraction): try c.put(fraction, "hpBelow")
        case let .hpAbove(fraction): try c.put(fraction, "hpAbove")
        }
    }
}

extension EnemyTrait {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        let key = try c.onlyKey()
        switch key {
        case "comboShield": self = .comboShield(minCombos: try c.value(key))
        case "enrage": self = .enrage(try c.value(key))
        case "regenerate": self = .regenerate(try c.value(key))
        case "absorb": self = .absorb(try c.value(key))
        case "armor": self = .armor(try c.value(key))
        default: throw c.unknown("enemy trait", key, key: key)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        switch self {
        case let .comboShield(minCombos): try c.put(minCombos, "comboShield")
        case let .enrage(fraction): try c.put(fraction, "enrage")
        case let .regenerate(fraction): try c.put(fraction, "regenerate")
        case let .absorb(element): try c.put(element, "absorb")
        case let .armor(amount): try c.put(amount, "armor")
        }
    }
}

// MARK: - Modifiers

extension Modifier {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        let type: String = try c.value("type")
        func fields(_ keys: String...) throws { try c.allowOnly(Set(keys + ["type"])) }

        switch type {
        case "flatDamage":
            try fields("element", "amount")
            self = .flatDamage(element: try c.optional("element"), amount: try c.value("amount"))
        case "damageMultiplier":
            try fields("element", "factor")
            self = .damageMultiplier(element: try c.optional("element"), factor: try c.value("factor"))
        case "clusterDamage":
            try fields("when", "element", "factor")
            self = .clusterDamage(try c.value("when"), element: try c.optional("element"), factor: try c.value("factor"))
        case "turnDamage":
            try fields("when", "factor")
            self = .turnDamage(try c.value("when"), factor: try c.value("factor"))
        case "comboBonus":
            try fields("amount")
            self = .comboBonus(try c.value("amount"))
        case "orbBonus":
            try fields("orb", "amount")
            self = .orbBonus(orb: try c.optional("orb"), amount: try c.value("amount"))
        case "flatHeal":
            try fields("amount")
            self = .flatHeal(try c.value("amount"))
        case "healMultiplier":
            try fields("factor")
            self = .healMultiplier(try c.value("factor"))
        case "maxHPMultiplier":
            try fields("factor")
            self = .maxHPMultiplier(try c.value("factor"))
        case "healOnTurnStart":
            try fields("amount")
            self = .healOnTurnStart(try c.value("amount"))
        case "turnHeal":
            try fields("when", "amount")
            self = .turnHeal(try c.value("when"), amount: try c.value("amount"))
        case "hpLossOnTurnStart":
            try fields("amount")
            self = .hpLossOnTurnStart(try c.value("amount"))
        case "turnSelfDamage":
            try fields("when", "amount")
            self = .turnSelfDamage(try c.value("when"), amount: try c.value("amount"))
        case "damageReduction":
            try fields("amount")
            self = .damageReduction(try c.value("amount"))
        case "damageTakenMultiplier":
            try fields("factor")
            self = .damageTakenMultiplier(try c.value("factor"))
        case "shieldOnTurnStart":
            try fields("amount")
            self = .shieldOnTurnStart(try c.value("amount"))
        case "turnShield":
            try fields("when", "amount")
            self = .turnShield(try c.value("when"), amount: try c.value("amount"))
        case "moveTime":
            try fields("seconds")
            self = .moveTime(try c.value("seconds"))
        default:
            throw c.unknown("modifier type", type, key: "type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        switch self {
        case let .flatDamage(element, amount):
            try c.put("flatDamage", "type"); try c.putIfPresent(element, "element"); try c.put(amount, "amount")
        case let .damageMultiplier(element, factor):
            try c.put("damageMultiplier", "type"); try c.putIfPresent(element, "element"); try c.put(factor, "factor")
        case let .clusterDamage(condition, element, factor):
            try c.put("clusterDamage", "type"); try c.put(condition, "when")
            try c.putIfPresent(element, "element"); try c.put(factor, "factor")
        case let .turnDamage(condition, factor):
            try c.put("turnDamage", "type"); try c.put(condition, "when"); try c.put(factor, "factor")
        case let .comboBonus(amount):
            try c.put("comboBonus", "type"); try c.put(amount, "amount")
        case let .orbBonus(orb, amount):
            try c.put("orbBonus", "type"); try c.putIfPresent(orb, "orb"); try c.put(amount, "amount")
        case let .flatHeal(amount):
            try c.put("flatHeal", "type"); try c.put(amount, "amount")
        case let .healMultiplier(factor):
            try c.put("healMultiplier", "type"); try c.put(factor, "factor")
        case let .maxHPMultiplier(factor):
            try c.put("maxHPMultiplier", "type"); try c.put(factor, "factor")
        case let .healOnTurnStart(amount):
            try c.put("healOnTurnStart", "type"); try c.put(amount, "amount")
        case let .turnHeal(condition, amount):
            try c.put("turnHeal", "type"); try c.put(condition, "when"); try c.put(amount, "amount")
        case let .hpLossOnTurnStart(amount):
            try c.put("hpLossOnTurnStart", "type"); try c.put(amount, "amount")
        case let .turnSelfDamage(condition, amount):
            try c.put("turnSelfDamage", "type"); try c.put(condition, "when"); try c.put(amount, "amount")
        case let .damageReduction(amount):
            try c.put("damageReduction", "type"); try c.put(amount, "amount")
        case let .damageTakenMultiplier(factor):
            try c.put("damageTakenMultiplier", "type"); try c.put(factor, "factor")
        case let .shieldOnTurnStart(amount):
            try c.put("shieldOnTurnStart", "type"); try c.put(amount, "amount")
        case let .turnShield(condition, amount):
            try c.put("turnShield", "type"); try c.put(condition, "when"); try c.put(amount, "amount")
        case let .moveTime(seconds):
            try c.put("moveTime", "type"); try c.put(seconds, "seconds")
        }
    }
}

// MARK: - Ability and event effects

extension AbilityEffect {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        let type: String = try c.value("type")
        func fields(_ keys: String...) throws { try c.allowOnly(Set(keys + ["type"])) }

        switch type {
        case "damage":
            try fields("target", "element", "multiplier")
            self = .damage(target: try c.value("target"), element: try c.value("element"), multiplier: try c.value("multiplier"))
        case "healPercent":
            try fields("fraction")
            self = .healPercent(try c.value("fraction"))
        case "shield":
            try fields("amount")
            self = .shield(try c.value("amount"))
        case "delayEnemies":
            try fields("turns")
            self = .delayEnemies(turns: try c.value("turns"))
        case "buff":
            try fields("name", "modifiers", "turns")
            self = .buff(ModifierSource(name: try c.value("name"), modifiers: try c.value("modifiers")), turns: try c.value("turns"))
        case "convertOrbs":
            try fields("from", "to")
            self = .convertOrbs(from: try c.value("from"), to: try c.value("to"))
        case "refreshBoard":
            try fields()
            self = .refreshBoard
        default:
            throw c.unknown("ability effect", type, key: "type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        switch self {
        case let .damage(target, element, multiplier):
            try c.put("damage", "type"); try c.put(target, "target")
            try c.put(element, "element"); try c.put(multiplier, "multiplier")
        case let .healPercent(fraction):
            try c.put("healPercent", "type"); try c.put(fraction, "fraction")
        case let .shield(amount):
            try c.put("shield", "type"); try c.put(amount, "amount")
        case let .delayEnemies(turns):
            try c.put("delayEnemies", "type"); try c.put(turns, "turns")
        case let .buff(source, turns):
            try c.put("buff", "type"); try c.put(source.name, "name")
            try c.put(source.modifiers, "modifiers"); try c.put(turns, "turns")
        case let .convertOrbs(from, to):
            try c.put("convertOrbs", "type"); try c.put(from, "from"); try c.put(to, "to")
        case .refreshBoard:
            try c.put("refreshBoard", "type")
        }
    }
}

extension EventEffect {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        let type: String = try c.value("type")
        func fields(_ keys: String...) throws { try c.allowOnly(Set(keys + ["type"])) }

        switch type {
        case "loseHP":
            try fields("fraction")
            self = .loseHP(try c.value("fraction"))
        case "heal":
            try fields("fraction")
            self = .heal(try c.value("fraction"))
        case "gainGold":
            try fields("amount")
            self = .gainGold(try c.value("amount"))
        case "loseGold":
            try fields("amount")
            self = .loseGold(try c.value("amount"))
        case "gainRelic":
            try fields("rarity")
            self = .gainRelic(try c.value("rarity"))
        case "levelUp":
            try fields()
            self = .levelUp
        case "fight":
            try fields("kind")
            self = .fight(try c.value("kind"))
        default:
            throw c.unknown("event effect", type, key: "type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyKey.self)
        switch self {
        case let .loseHP(fraction): try c.put("loseHP", "type"); try c.put(fraction, "fraction")
        case let .heal(fraction): try c.put("heal", "type"); try c.put(fraction, "fraction")
        case let .gainGold(amount): try c.put("gainGold", "type"); try c.put(amount, "amount")
        case let .loseGold(amount): try c.put("loseGold", "type"); try c.put(amount, "amount")
        case let .gainRelic(rarity): try c.put("gainRelic", "type"); try c.put(rarity, "rarity")
        case .levelUp: try c.put("levelUp", "type")
        case let .fight(kind): try c.put("fight", "type"); try c.put(kind, "kind")
        }
    }
}

// MARK: - Content records (optional fields get defaults, unknown fields are rejected)

extension Relic {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        try c.allowOnly(["id", "name", "rarity", "flavor", "modifiers"])
        self.init(id: try c.value("id"), name: try c.value("name"), rarity: try c.value("rarity"),
                  flavor: try c.optional("flavor") ?? "", modifiers: try c.value("modifiers"))
    }
}

extension PassiveTalent {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        try c.allowOnly(["id", "name", "unlockLevel", "modifiers"])
        self.init(id: try c.value("id"), name: try c.value("name"), unlockLevel: try c.value("unlockLevel"),
                  modifiers: try c.value("modifiers"))
    }
}

extension Ability {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        try c.allowOnly(["id", "name", "cooldown", "charges", "hpCost", "effects"])
        self.init(id: try c.value("id"), name: try c.value("name"), cooldown: try c.value("cooldown"),
                  charges: try c.optional("charges"), hpCost: try c.optional("hpCost") ?? 0, effects: try c.value("effects"))
    }
}

extension CharacterDefinition {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        try c.allowOnly(["id", "name", "element", "title", "playstyle", "baseHP", "baseAttack", "baseRecovery",
                         "talents", "abilities"])
        self.init(id: try c.value("id"), name: try c.value("name"), element: try c.value("element"),
                  title: try c.optional("title") ?? "", playstyle: try c.optional("playstyle") ?? "",
                  baseHP: try c.value("baseHP"), baseAttack: try c.value("baseAttack"),
                  baseRecovery: try c.value("baseRecovery"),
                  talents: try c.optional("talents") ?? [], abilities: try c.optional("abilities") ?? [])
    }
}

extension EnemyTemplate {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        try c.allowOnly(["name", "element", "tier", "baseHP", "baseAttack", "turnInterval", "traits", "minRow"])
        self.init(name: try c.value("name"), element: try c.value("element"), tier: try c.value("tier"),
                  baseHP: try c.value("baseHP"), baseAttack: try c.value("baseAttack"),
                  turnInterval: try c.value("turnInterval"), traits: try c.optional("traits") ?? [],
                  minRow: try c.optional("minRow") ?? 0)
    }
}

extension EventOption {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        try c.allowOnly(["label", "effects"])
        self.init(try c.value("label"), try c.optional("effects") ?? [])
    }
}

extension RunEvent {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        try c.allowOnly(["id", "title", "text", "options"])
        self.init(id: try c.value("id"), title: try c.value("title"), text: try c.value("text"),
                  options: try c.value("options"))
    }
}
