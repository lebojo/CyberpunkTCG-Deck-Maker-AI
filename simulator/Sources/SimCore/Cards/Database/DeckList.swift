import Foundation

public struct DeckList: Sendable {
    public let name: String
    public let legends: [Int]
    public let main: [Int]
    public let problems: [String]

    public init(name: String, legends: [Int], main: [Int], problems: [String] = []) {
        self.name = name
        self.legends = legends
        self.main = main
        self.problems = problems
    }

    public var allCards: [Int] { legends + main }

    public static func validationError(for decks: [DeckList]) -> String? {
        let invalid = decks.filter { !$0.problems.isEmpty }
        guard !invalid.isEmpty else { return nil }
        let details = invalid.map { "  \($0.name) : " + $0.problems.joined(separator: "; ") }
        return (["Simulation impossible, deck(s) invalide(s) :"] + details + ["Un deck doit avoir exactement 3 Légendes connues et 40 à 50 cartes connues dans son main deck."]).joined(separator: "\n")
    }

    public static func load(path: String, catalog: CardCatalog) throws -> DeckList {
        let text = try String(contentsOfFile: path, encoding: .utf8)
        let fallback = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        return parse(text: text, fallbackName: fallback, catalog: catalog)
    }

    public static func parse(text: String, fallbackName: String, catalog: CardCatalog) -> DeckList {
        var name = fallbackName
        var legends: [Int] = []
        var main: [Int] = []
        var problems: [String] = []
        var inLegends = false
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# Name:") {
                name = trimmed.dropFirst("# Name:".count).trimmingCharacters(in: .whitespaces)
                continue
            }
            if trimmed.hasPrefix("# Legends") { inLegends = true; continue }
            if trimmed.hasPrefix("# Main") { inLegends = false; continue }
            guard let entry = parseEntry(trimmed) else { continue }
            guard let id = catalog.id(named: entry.name) else {
                problems.append("Carte inconnue : \(entry.name)")
                continue
            }
            if inLegends { legends.append(id) } else { main.append(contentsOf: Array(repeating: id, count: entry.quantity)) }
        }
        if legends.count != 3 { problems.append("\(legends.count) Légendes au lieu de 3") }
        if main.count < 40 || main.count > 50 { problems.append("\(main.count) cartes dans le main deck") }
        return DeckList(name: name, legends: legends, main: main, problems: problems)
    }

    private static func parseEntry(_ line: String) -> (quantity: Int, name: String)? {
        let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard parts.count == 3, parts[0].hasSuffix("x"), let quantity = Int(parts[0].dropLast()) else { return nil }
        return (quantity, String(parts[2]))
    }
}
