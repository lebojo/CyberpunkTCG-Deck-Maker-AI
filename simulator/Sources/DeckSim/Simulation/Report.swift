import Foundation

enum Report {
    static func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    static func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
    }

    static func duel(a: DeckList, b: DeckList, stats: DuelStats) -> String {
        var lines: [String] = []
        lines.append("\(a.name)  vs  \(b.name)  (\(stats.games) parties)")
        lines.append("")
        lines.append("  \(pad(a.name, 34)) \(percent(stats.scoreA))  ±\(percent(stats.confidenceMargin))  (\(stats.winsA) victoires)")
        lines.append("  \(pad(b.name, 34)) \(percent(1 - stats.scoreA))  ±\(percent(stats.confidenceMargin))  (\(stats.winsB) victoires)")
        if stats.draws > 0 { lines.append("  égalités / limite de tours : \(stats.draws)") }
        lines.append("")
        if stats.gamesAWhenFirst > 0 && stats.gamesAWhenSecond > 0 {
            let first = Double(stats.winsAWhenFirst) / Double(stats.gamesAWhenFirst)
            let second = Double(stats.winsAWhenSecond) / Double(stats.gamesAWhenSecond)
            lines.append("  \(a.name) en jouant en premier : \(percent(first))   en second : \(percent(second))")
        }
        lines.append("  durée moyenne : \(String(format: "%.1f", Double(stats.turnSum) / Double(max(1, stats.games)))) tours au total (≈ \(String(format: "%.1f", Double(stats.turnSum) / Double(max(1, stats.games)) / 2)) par joueur)")
        lines.append("  mulligans : \(a.name) \(percent(Double(stats.mulligansA) / Double(max(1, stats.games)))), \(b.name) \(percent(Double(stats.mulligansB) / Double(max(1, stats.games))))")
        let reasons = stats.reasons.sorted { $0.value > $1.value }.map { "\($0.key) \(percent(Double($0.value) / Double(max(1, stats.games))))" }
        lines.append("  fins de partie : " + reasons.joined(separator: ", "))
        return lines.joined(separator: "\n")
    }

    static func matrix(decks: [DeckList], scores: [[Double?]]) -> String {
        var lines: [String] = []
        let names = decks.map { String($0.name.prefix(22)) }
        lines.append(pad("", 24) + names.indices.map { pad("#\($0 + 1)", 8) }.joined() + "moyenne")
        let ranking = decks.indices.map { row -> (Int, Double) in
            let values = scores[row].compactMap { $0 }
            return (row, values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count))
        }
        for row in decks.indices {
            var line = pad("#\(row + 1) \(names[row])", 24)
            for column in decks.indices {
                line += pad(scores[row][column].map { percent($0) } ?? "  -", 8)
            }
            line += percent(ranking[row].1)
            lines.append(line)
        }
        lines.append("")
        lines.append("Classement (win rate moyen contre le reste du lot) :")
        for (rank, entry) in ranking.sorted(by: { $0.1 > $1.1 }).enumerated() {
            lines.append("  \(rank + 1). \(decks[entry.0].name)  \(percent(entry.1))")
        }
        return lines.joined(separator: "\n")
    }

    static func tournament(decks: [DeckList], stats: TournamentStats, bestOf: Int) -> String {
        let n = Double(max(1, stats.tournaments))
        let baseline = 1.0 / Double(decks.count)
        var lines: [String] = []
        lines.append("\(stats.tournaments) tournois à élimination directe, \(decks.count) decks, matchs en BO\(bestOf), ordre de départ aléatoire à chaque tournoi")
        lines.append("Un deck qui gagnerait au hasard remporterait \(percent(baseline)) des tournois.")
        lines.append("")
        lines.append(pad("#", 3) + pad("Deck", 44) + pad("Tournois", 17) + pad("Finales", 10) + pad("Matchs", 10) + "Parties")
        let order = decks.indices.sorted { stats.titles[$0] > stats.titles[$1] }
        for (rank, index) in order.enumerated() {
            let title = Double(stats.titles[index]) / n
            let margin = 1.96 * (title * (1 - title) / n).squareRoot()
            let finals = Double(stats.finals[index]) / n
            let matches = Double(stats.matchesWon[index]) / Double(max(1, stats.matchesPlayed[index]))
            let games = Double(stats.gamesWon[index]) / Double(max(1, stats.gamesPlayed[index]))
            lines.append(pad("\(rank + 1)", 3) + pad(String(decks[index].name.prefix(42)), 44) + pad("\(percent(title)) ±\(percent(margin))", 17) + pad(percent(finals), 10) + pad(percent(matches), 10) + percent(games))
        }
        return lines.joined(separator: "\n")
    }

    static func unsupportedCards(decks: [DeckList], catalog: CardCatalog) -> [String] {
        var names = Set<String>()
        for deck in decks {
            for id in deck.legends + deck.main {
                let card = catalog.cards[id]
                if case .vanilla = card.behavior, !card.text.isEmpty, !card.text.contains("[Flavor]") { names.insert(card.name) }
            }
        }
        return names.sorted()
    }
}
