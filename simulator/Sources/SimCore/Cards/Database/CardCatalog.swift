import Foundation

public struct CardStats: Sendable {
    public let kind: CardKind
    public let color: CardColor?
    public let cost: Int?
    public let costValue: Int
    public let power: Int
    public let isSellable: Bool
    public let mentionsMinGig: Bool

    init(_ data: CardData) {
        kind = data.kind
        color = data.color
        cost = data.cost
        costValue = data.costValue
        power = data.power
        isSellable = data.isSellable
        mentionsMinGig = data.mentionsMinGig
    }
}

struct CardProfile: Sendable {
    let listens: EventMask
    let keywords: Keyword
    let scopes: ModifierScopes
    let hints: AIHints
    let abilityTimings: AbilityTimings
    let isDedicated: Bool

    init(_ card: any GameCard) {
        listens = card.listens
        keywords = card.keywords
        scopes = card.modifierScopes
        hints = card.hints
        abilityTimings = AbilityTimings(card.abilities.map(\.timing))
        isDedicated = !(card is VanillaCard)
    }
}

public final class CardCatalog: Sendable {
    public let data: [CardData]
    let cards: [any GameCard]
    let stats: [CardStats]
    let profiles: [CardProfile]
    let abilities: [[ActivatedAbility]]
    let idByName: [String: Int]
    let idByKey: [String: Int]
    let registry: CardRegistry

    public init(data: [CardData], registry: CardRegistry = .standard) {
        self.data = data
        self.registry = registry
        let built = data.map { registry.make($0) }
        cards = built
        stats = data.map(CardStats.init)
        profiles = built.map(CardProfile.init)
        abilities = built.map(\.abilities)
        var names: [String: Int] = [:]
        var keys: [String: Int] = [:]
        for (id, entry) in data.enumerated() {
            names[CardName.normalize(entry.canonicalName)] = id
            keys[entry.key] = id
        }
        idByName = names
        idByKey = keys
    }

    public static func embedded() throws -> CardCatalog {
        CardCatalog(data: try CardDatabase.load())
    }

    public func isolatedCopy() -> CardCatalog {
        CardCatalog(data: data.map(\.isolatedCopy), registry: registry)
    }

    public var count: Int { data.count }

    public func id(named name: String) -> Int? {
        idByName[CardName.normalize(name)]
    }

    public func id(key: String) -> Int? {
        idByKey[key]
    }

    public func isDedicated(_ id: Int) -> Bool {
        profiles[id].isDedicated
    }

    public func implementationName(_ id: Int) -> String {
        String(describing: type(of: cards[id]))
    }
}

public enum CardName {
    public static func normalize(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: " - ", with: "-")
            .replacingOccurrences(of: "’", with: "'")
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }
}
