import Foundation

/// Passive bonus of a character, active once the character reaches `unlockLevel`.
public struct PassiveTalent: Hashable, Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let unlockLevel: Int
    public let modifiers: [Modifier]

    public init(id: String, name: String, unlockLevel: Int, modifiers: [Modifier]) {
        self.id = id
        self.name = name
        self.unlockLevel = unlockLevel
        self.modifiers = modifiers
    }
}

/// The single hero of a run. Attacks with every element; its own element gets the affinity bonus.
public struct CharacterDefinition: Hashable, Codable, Sendable, Identifiable {
    public static let maxLevel = 5
    /// Stat growth per level above 1, as a fraction of the base stat.
    public static let growthPerLevel = 0.1
    public static let affinityMultiplier = 1.5

    public let id: String
    public let name: String
    public let element: Element
    public let title: String
    /// One sentence on how the hero wants to be played.
    public let playstyle: String
    public let baseHP: Int
    public let baseAttack: Int
    public let baseRecovery: Int
    public let talents: [PassiveTalent]
    public let abilities: [Ability]

    public init(id: String, name: String, element: Element, title: String = "", playstyle: String = "",
                baseHP: Int, baseAttack: Int, baseRecovery: Int,
                talents: [PassiveTalent] = [], abilities: [Ability] = []) {
        self.id = id
        self.name = name
        self.element = element
        self.title = title
        self.playstyle = playstyle
        self.baseHP = baseHP
        self.baseAttack = baseAttack
        self.baseRecovery = baseRecovery
        self.talents = talents
        self.abilities = abilities
    }

    public func hp(at level: Int) -> Int { scaled(baseHP, level) }
    public func attack(at level: Int) -> Int { scaled(baseAttack, level) }
    public func recovery(at level: Int) -> Int { scaled(baseRecovery, level) }

    public func unlockedTalents(at level: Int) -> [PassiveTalent] {
        talents.filter { $0.unlockLevel <= level }
    }

    /// Element affinity first, then the talents unlocked at `level`.
    public func modifierSources(at level: Int) -> [ModifierSource] {
        let affinity = ModifierSource(name: "\(name): Affinità",
                                      modifiers: [.damageMultiplier(element: element, factor: Self.affinityMultiplier)])
        return [affinity] + unlockedTalents(at: level).map {
            ModifierSource(name: "\(name): \($0.name)", modifiers: $0.modifiers)
        }
    }

    public var abilityStates: [AbilityState] {
        abilities.map { AbilityState(ability: $0, owner: name) }
    }

    /// `resolver` applies max-HP modifiers; `missingHP` carries damage over between battles.
    public func makePlayer(level: Int, resolver: ModifierResolver = ModifierResolver(), missingHP: Int = 0) -> Player {
        let attack = attack(at: level)
        let maxHP = resolver.maxHP(hp(at: level)).value
        return Player(maxHP: maxHP,
                      attack: Dictionary(uniqueKeysWithValues: Element.allCases.map { ($0, attack) }),
                      recovery: recovery(at: level),
                      currentHP: maxHP - max(0, missingHP))
    }

    private func scaled(_ base: Int, _ level: Int) -> Int {
        let level = min(max(level, 1), Self.maxLevel)
        return Int((Double(base) * (1 + Self.growthPerLevel * Double(level - 1))).rounded())
    }
}
