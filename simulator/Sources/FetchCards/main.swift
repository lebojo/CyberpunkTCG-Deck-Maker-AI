import Foundation

struct FetchOptions {
    var output = "Sources/SimCore/Resources/cards.json"
    var dryRun = false

    static func parse(_ arguments: [String]) -> FetchOptions {
        var options = FetchOptions()
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--output": if let value = iterator.next() { options.output = value }
            case "--dry-run": options.dryRun = true
            default: print("Option ignorée : \(argument)")
            }
        }
        return options
    }
}

func readExistingCards(at path: String) throws -> [JSONValue] {
    guard FileManager.default.fileExists(atPath: path) else { return [] }
    guard let data = FileManager.default.contents(atPath: path),
          let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let cards = root["cards"] as? [[String: Any]] else { throw FetchError.unreadable(path) }
    return cards.map { card in
        .object((["key"] + CardNormalizer.fields.map(\.output)).map { ($0, JSONValue(any: card[$0])) })
    }
}

func describeChanges(old: [JSONValue], new: [JSONValue]) -> [String] {
    let previous = Dictionary(old.compactMap { card in card["key"]?.stringValue.map { ($0, card) } }, uniquingKeysWith: { first, _ in first })
    var lines: [String] = []
    for card in new {
        guard let key = card["key"]?.stringValue else { continue }
        guard let before = previous[key] else {
            lines.append("+ \(key)")
            continue
        }
        let changed = CardNormalizer.fields.map(\.output).filter { before[$0] != card[$0] }
        if !changed.isEmpty { lines.append("~ \(key) : " + changed.joined(separator: ", ")) }
    }
    let currentKeys = Set(new.compactMap { $0["key"]?.stringValue })
    for key in previous.keys.sorted() where !currentKeys.contains(key) { lines.append("- \(key)") }
    return lines
}

func run() async throws {
    let options = FetchOptions.parse(Array(CommandLine.arguments.dropFirst()))
    let existing = try readExistingCards(at: options.output)
    print("Téléchargement des cartes depuis NetDeck…")
    let raw = try await NetDeckClient.fetchAll()
    let cards = CardNormalizer.sorted(raw.map(CardNormalizer.normalize))
    guard cards.count >= existing.count else { throw FetchError.shrinking(old: existing.count, new: cards.count) }
    let changes = describeChanges(old: existing, new: cards)
    print("\(cards.count) cartes (avant : \(existing.count))")
    print(changes.isEmpty ? "Aucune carte ajoutée ni modifiée." : changes.joined(separator: "\n"))
    let file = JSONValue.object([
        ("schemaVersion", .number(1)),
        ("source", .string(NetDeckClient.source)),
        ("cards", .array(cards)),
    ])
    guard !options.dryRun else { return }
    try file.serialized(indent: 0).write(toFile: options.output, atomically: true, encoding: .utf8)
    print("Écrit : \(options.output)")
}

do {
    try await run()
} catch {
    print(error)
    exit(1)
}
