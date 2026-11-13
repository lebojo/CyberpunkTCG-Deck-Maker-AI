public enum CoverageStatus: Sendable, Equatable {
    case dedicated
    case keywordsOnly
    case flavorOnly
    case missing([String])
}

public struct CoverageEntry: Sendable {
    public let id: Int
    public let data: CardData
    public let status: CoverageStatus
}

public enum CoverageReport {
    public static func entries(_ catalog: CardCatalog) -> [CoverageEntry] {
        catalog.data.indices.map { id in
            CoverageEntry(id: id, data: catalog.data[id], status: status(of: id, in: catalog))
        }
    }

    public static func status(of id: Int, in catalog: CardCatalog) -> CoverageStatus {
        let card = catalog.cards[id]
        if card is KeywordCard { return .keywordsOnly }
        if catalog.isDedicated(id) { return .dedicated }
        let text = catalog.data[id].rulesText
        if RulesText.isFlavorOnly(text) { return .flavorOnly }
        let missing = RulesText.effectLines(text)
        return missing.isEmpty ? .keywordsOnly : .missing(missing)
    }

    public static func missingCards(in decks: [DeckList], catalog: CardCatalog) -> [String] {
        let ids = Set(decks.flatMap(\.allCards))
        return ids.filter { if case .missing = status(of: $0, in: catalog) { return true } else { return false } }
            .map { catalog.data[$0].canonicalName }
            .sorted()
    }

    public static func text(_ catalog: CardCatalog) -> String {
        let all = entries(catalog)
        var lines: [String] = []
        let dedicated = all.filter { $0.status == .dedicated }.count
        let keywords = all.filter { $0.status == .keywordsOnly }.count
        let flavor = all.filter { $0.status == .flavorOnly }.count
        let missing = all.filter { isMissing($0.status) }
        lines.append("Couverture des effets : \(all.count) cartes dans la base")
        lines.append("  implémentation dédiée : \(dedicated)")
        lines.append("  mots-clés seuls (VanillaCard/KeywordCard) : \(keywords)")
        lines.append("  texte d'ambiance uniquement : \(flavor)")
        lines.append("  à coder (VanillaCard avec du vrai texte de règles) : \(missing.count)")
        for color in colorGroups {
            let inColor = all.filter { $0.data.color == color }
            guard !inColor.isEmpty else { continue }
            lines.append("")
            lines.append("== \(color?.frenchName ?? "Sans couleur") ==")
            for kind in CardKind.allCases {
                let group = inColor.filter { $0.data.kind == kind }
                guard !group.isEmpty else { continue }
                let done = group.filter { !isMissing($0.status) }
                let todo = group.filter { isMissing($0.status) }
                lines.append("  \(kind.frenchName) : \(done.count) couvertes, \(todo.count) à coder")
                for entry in done {
                    lines.append("    [\(label(entry.status))]  \(entry.data.canonicalName)  (\(entry.data.key))")
                }
                for entry in todo {
                    lines.append("    [à coder]    \(entry.data.canonicalName)  (\(entry.data.key))")
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    static let colorGroups: [CardColor?] = CardColor.allCases.map { Optional($0) } + [nil]

    static func label(_ status: CoverageStatus) -> String {
        switch status {
        case .dedicated: return "dédiée"
        case .keywordsOnly: return "mots-clés"
        case .flavorOnly: return "ambiance"
        case .missing: return "à coder"
        }
    }

    static func isMissing(_ status: CoverageStatus) -> Bool {
        if case .missing = status { return true }
        return false
    }
}
