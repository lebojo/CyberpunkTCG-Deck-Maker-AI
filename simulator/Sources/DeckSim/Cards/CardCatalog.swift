import Foundation

struct RawCard: Codable, Sendable {
    let name: String
    let canonical_base_name: String?
    let canonical_name: String?
    let display_name: String?
    let card_type: String
    let color: String?
    let cost: Int?
    let power: Int?
    let ram: Int?
    let is_eddiable: Bool?
    let classifications: [String]?
    let rules_text: String?
    let legality: String?
}

struct RawPage: Codable, Sendable {
    let items: [RawCard]
    let total: Int
}

enum CatalogError: Error, CustomStringConvertible {
    case network(String)

    var description: String {
        switch self {
        case .network(let message): return "Impossible de charger les cartes : \(message)"
        }
    }
}

struct CardCatalog: Sendable {
    let cards: [Card]
    let idByName: [String: Int]

    init(raw: [RawCard]) {
        var built: [Card] = []
        var index: [String: Int] = [:]
        for (offset, item) in raw.enumerated() {
            guard let kind = CardKind(rawValue: item.card_type) else { continue }
            let fullName = item.canonical_name ?? item.display_name ?? item.name
            let card = Card(
                id: offset,
                name: fullName,
                kind: kind,
                color: item.color ?? "",
                cost: item.cost,
                power: item.power ?? 0,
                sellable: item.is_eddiable ?? false,
                tags: Set((item.classifications ?? []).map { $0.lowercased() }),
                text: (item.rules_text ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                behavior: Behavior(name: fullName)
            )
            built.append(card)
            index[Behavior.normalize(fullName)] = card.id
        }
        cards = built
        idByName = index
    }

    func id(named name: String) -> Int? {
        idByName[Behavior.normalize(name)]
    }

    static func load(cachePath: String) async throws -> CardCatalog {
        if let data = FileManager.default.contents(atPath: cachePath),
           let raw = try? JSONDecoder().decode([RawCard].self, from: data) {
            return CardCatalog(raw: raw)
        }
        let raw = try await fetchAll()
        let directory = (cachePath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(raw).write(to: URL(fileURLWithPath: cachePath))
        return CardCatalog(raw: raw)
    }

    private static func fetchAll() async throws -> [RawCard] {
        var items: [RawCard] = []
        var total = Int.max
        while items.count < total {
            guard let url = URL(string: "https://api.netdeck.gg/api/cards/cyberpunk?limit=100&offset=\(items.count)") else {
                throw CatalogError.network("URL invalide")
            }
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw CatalogError.network("réponse HTTP inattendue")
            }
            let page = try JSONDecoder().decode(RawPage.self, from: data)
            total = page.total
            if page.items.isEmpty { break }
            items.append(contentsOf: page.items)
        }
        return items
    }
}
