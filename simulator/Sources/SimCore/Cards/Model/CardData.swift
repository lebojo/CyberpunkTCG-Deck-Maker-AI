public struct CardData: Sendable, Hashable {
    public let key: String
    public let name: String
    public let subname: String?
    public let canonicalName: String
    public let kind: CardKind
    public let color: CardColor?
    public let cost: Int?
    public let power: Int
    public let ram: Int?
    public let isSellable: Bool
    public let tags: Set<CardTag>
    public let rulesText: String
    public let printNumber: String?
    public let legality: String?

    public init(
        key: String,
        name: String,
        subname: String? = nil,
        canonicalName: String,
        kind: CardKind,
        color: CardColor?,
        cost: Int?,
        power: Int,
        ram: Int? = nil,
        isSellable: Bool,
        tags: Set<CardTag>,
        rulesText: String,
        printNumber: String? = nil,
        legality: String? = nil
    ) {
        self.key = key
        self.name = name
        self.subname = subname
        self.canonicalName = canonicalName
        self.kind = kind
        self.color = color
        self.cost = cost
        self.power = power
        self.ram = ram
        self.isSellable = isSellable
        self.tags = tags
        self.rulesText = rulesText
        self.printNumber = printNumber
        self.legality = legality
    }

    public var costValue: Int { cost ?? 0 }

    var isolatedCopy: CardData {
        CardData(
            key: Self.fresh(key),
            name: Self.fresh(name),
            subname: subname.map(Self.fresh),
            canonicalName: Self.fresh(canonicalName),
            kind: kind,
            color: color,
            cost: cost,
            power: power,
            ram: ram,
            isSellable: isSellable,
            tags: Set(tags.map { CardTag(rawValue: Self.fresh($0.rawValue)) }),
            rulesText: Self.fresh(rulesText),
            printNumber: printNumber.map(Self.fresh),
            legality: legality.map(Self.fresh)
        )
    }

    static func fresh(_ text: String) -> String {
        String(decoding: Array(text.utf8), as: UTF8.self)
    }

    public func has(_ tag: CardTag) -> Bool { tags.contains(tag) }

    public func isColor(_ wanted: CardColor) -> Bool { color == wanted }

    public var mentionsMinGig: Bool { rulesText.lowercased().contains("min gig") }

    public var hasGoSolo: Bool { rulesText.contains("{Go Solo}") }
}
