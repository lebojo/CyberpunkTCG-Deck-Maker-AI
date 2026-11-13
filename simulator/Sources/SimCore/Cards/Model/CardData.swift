enum CardKind: String, Sendable {
    case legend = "Legend"
    case unit = "Unit"
    case gear = "Gear"
    case program = "Program"
}

struct Card: Sendable {
    let id: Int
    let name: String
    let kind: CardKind
    let color: String
    let cost: Int?
    let power: Int
    let sellable: Bool
    let tags: Set<String>
    let text: String
    let behavior: Behavior

    var costValue: Int { cost ?? 0 }
    var isBlue: Bool { color == "Blue" }
    var isArasaka: Bool { tags.contains("arasaka") }
    var isCorpo: Bool { tags.contains("corpo") }
    var isMerc: Bool { tags.contains("merc") }
    var isCyberware: Bool { tags.contains("cyberware") }
    var isBraindance: Bool { tags.contains("braindance") }
    var mentionsMinGig: Bool { text.lowercased().contains("min gig") }
}
