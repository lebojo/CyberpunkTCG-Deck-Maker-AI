import Foundation

struct CardRecord: Decodable, Sendable {
    let key: String
    let name: String
    let subname: String?
    let canonicalName: String
    let kind: String
    let color: String?
    let cost: Int?
    let power: Int?
    let ram: Int?
    let sellable: Bool?
    let classifications: [String]?
    let rulesText: String?
    let printNumber: String?
    let legality: String?

    var cardData: CardData? {
        guard let cardKind = CardKind(rawValue: kind) else { return nil }
        return CardData(
            key: key,
            name: name,
            subname: subname,
            canonicalName: canonicalName,
            kind: cardKind,
            color: color.flatMap(CardColor.init(rawValue:)),
            cost: cost,
            power: power ?? 0,
            ram: ram,
            isSellable: sellable ?? false,
            tags: Set((classifications ?? []).map(CardTag.init(rawValue:))),
            rulesText: (rulesText ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            printNumber: printNumber,
            legality: legality
        )
    }
}

struct CardFile: Decodable, Sendable {
    let schemaVersion: Int
    let source: String?
    let cards: [CardRecord]
}

public enum CardDatabaseError: Error, CustomStringConvertible {
    case missingResource
    case unsupportedSchema(Int)

    public var description: String {
        switch self {
        case .missingResource: return "Base de cartes embarquée introuvable (cards.json)"
        case .unsupportedSchema(let version): return "Version de schéma de cards.json non prise en charge : \(version)"
        }
    }
}

public enum CardDatabase {
    public static let supportedSchemaVersion = 1

    public static func load() throws -> [CardData] {
        guard let url = Bundle.module.url(forResource: "cards", withExtension: "json") else {
            throw CardDatabaseError.missingResource
        }
        return try decode(Data(contentsOf: url))
    }

    public static func decode(_ data: Data) throws -> [CardData] {
        let file = try JSONDecoder().decode(CardFile.self, from: data)
        guard file.schemaVersion == supportedSchemaVersion else {
            throw CardDatabaseError.unsupportedSchema(file.schemaVersion)
        }
        return file.cards.compactMap(\.cardData)
    }
}
