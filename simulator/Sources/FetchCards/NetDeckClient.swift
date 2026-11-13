import Foundation

enum FetchError: Error, CustomStringConvertible {
    case badResponse(String)
    case shrinking(old: Int, new: Int)
    case unreadable(String)

    var description: String {
        switch self {
        case .badResponse(let message): return "Réponse NetDeck inattendue : \(message)"
        case .shrinking(let old, let new): return "Refus : la base passerait de \(old) à \(new) cartes"
        case .unreadable(let path): return "Impossible de lire \(path)"
        }
    }
}

enum NetDeckClient {
    static let source = "https://api.netdeck.gg/api/cards/cyberpunk"

    static func fetchAll() async throws -> [[String: Any]] {
        var items: [[String: Any]] = []
        var total = Int.max
        while items.count < total {
            guard let url = URL(string: "\(source)?limit=100&offset=\(items.count)") else { throw FetchError.badResponse("URL invalide") }
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw FetchError.badResponse("code HTTP différent de 200") }
            guard let page = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pageItems = page["items"] as? [[String: Any]],
                  let pageTotal = page["total"] as? Int else { throw FetchError.badResponse("page illisible") }
            total = pageTotal
            if pageItems.isEmpty { break }
            items.append(contentsOf: pageItems)
        }
        return items
    }
}
