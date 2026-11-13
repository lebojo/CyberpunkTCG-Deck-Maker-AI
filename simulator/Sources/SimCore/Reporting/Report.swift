import Foundation

public enum Report {
    public static func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    public static func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
    }

    public static func duel(a: DeckList, b: DeckList, stats: DuelStats) -> String {
        var lines: [String] = []
        lines.append("\(a.name)  vs  \(b.name)  (\(stats.games) parties)")
        lines.append("")
        lines.append("  \(pad(a.name, 34)) \(percent(stats.scoreA))  ±\(percent(stats.confidenceMargin))  (\(stats.winsA) victoires)")
        lines.append("  \(pad(b.name, 34)) \(percent(1 - stats.scoreA))  ±\(percent(stats.confidenceMargin))  (\(stats.winsB) victoires)")
        if stats.draws > 0 { lines.append("  égalités : \(stats.draws)") }
        lines.append("")
        if stats.gamesAWhenFirst > 0 && stats.gamesAWhenSecond > 0 {
            let first = Double(stats.winsAWhenFirst) / Double(stats.gamesAWhenFirst)
            let second = Double(stats.winsAWhenSecond) / Double(stats.gamesAWhenSecond)
            lines.append("  \(a.name) en jouant en premier : \(percent(first))   en second : \(percent(second))")
        }
        lines.append("  durée moyenne : \(String(format: "%.1f", Double(stats.turnSum) / Double(max(1, stats.games)))) tours au total (≈ \(String(format: "%.1f", Double(stats.turnSum) / Double(max(1, stats.games)) / 2)) par joueur)")
        lines.append("  mulligans : \(a.name) \(percent(Double(stats.mulligansA) / Double(max(1, stats.games)))), \(b.name) \(percent(Double(stats.mulligansB) / Double(max(1, stats.games))))")
        lines.append("  fins de partie : " + endings(stats))
        return lines.joined(separator: "\n")
    }

    static func endings(_ stats: DuelStats) -> String {
        stats.reasons.sorted { $0.value > $1.value }.map { "\($0.key) \(percent(Double($0.value) / Double(max(1, stats.games))))" }.joined(separator: ", ")
    }

    public static func matrix(decks: [DeckList], scores: [[Double?]]) -> String {
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

    public static func tournament(decks: [DeckList], stats: TournamentStats, bestOf: Int) -> String {
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

    public static func markdownCell(_ text: String) -> String {
        text.replacingOccurrences(of: "|", with: "\\|")
    }

    public static func tournamentMarkdown(decks: [DeckList], stats: TournamentStats, bestOf: Int) -> String {
        let n = Double(max(1, stats.tournaments))
        var lines: [String] = []
        lines.append("# Résultats de tournois")
        lines.append("")
        lines.append("\(stats.tournaments) tournois à élimination directe, \(decks.count) decks, matchs en BO\(bestOf), ordre de départ aléatoire à chaque tournoi.")
        lines.append("Un deck qui gagnerait au hasard remporterait \(percent(1.0 / Double(decks.count))) des tournois.")
        lines.append("")
        lines.append("| # | Deck | Tournois gagnés | Finales | Matchs gagnés | Parties gagnées |")
        lines.append("|---|---|---|---|---|---|")
        let order = decks.indices.sorted { stats.titles[$0] > stats.titles[$1] }
        for (rank, index) in order.enumerated() {
            let title = Double(stats.titles[index]) / n
            let margin = 1.96 * (title * (1 - title) / n).squareRoot()
            let finals = Double(stats.finals[index]) / n
            let matches = Double(stats.matchesWon[index]) / Double(max(1, stats.matchesPlayed[index]))
            let games = Double(stats.gamesWon[index]) / Double(max(1, stats.gamesPlayed[index]))
            lines.append("| \(rank + 1) | \(markdownCell(decks[index].name)) | **\(percent(title))** ±\(percent(margin)) | \(percent(finals)) | \(percent(matches)) | \(percent(games)) |")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func matrixMarkdown(decks: [DeckList], scores: [[Double?]]) -> String {
        var lines: [String] = []
        lines.append("# Matrice des duels")
        lines.append("")
        lines.append("Win rate de la ligne contre la colonne.")
        lines.append("")
        lines.append("| Deck | " + decks.indices.map { "#\($0 + 1)" }.joined(separator: " | ") + " | Moyenne |")
        lines.append("|---|" + String(repeating: "---|", count: decks.count + 1))
        var averages: [(Int, Double)] = []
        for row in decks.indices {
            let values = scores[row].compactMap { $0 }
            let average = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
            averages.append((row, average))
            let cells = decks.indices.map { scores[row][$0].map { percent($0) } ?? "-" }
            lines.append("| #\(row + 1) \(markdownCell(decks[row].name)) | " + cells.joined(separator: " | ") + " | **\(percent(average))** |")
        }
        lines.append("")
        lines.append("## Classement")
        lines.append("")
        lines.append("| # | Deck | Win rate moyen |")
        lines.append("|---|---|---|")
        for (rank, entry) in averages.sorted(by: { $0.1 > $1.1 }).enumerated() {
            lines.append("| \(rank + 1) | \(markdownCell(decks[entry.0].name)) | \(percent(entry.1)) |")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func duelMarkdown(a: DeckList, b: DeckList, stats: DuelStats) -> String {
        var lines: [String] = []
        lines.append("# \(markdownCell(a.name)) vs \(markdownCell(b.name))")
        lines.append("")
        lines.append("\(stats.games) parties, marge d'erreur ±\(percent(stats.confidenceMargin)).")
        lines.append("")
        lines.append("| Deck | Win rate | Victoires |")
        lines.append("|---|---|---|")
        lines.append("| \(markdownCell(a.name)) | **\(percent(stats.scoreA))** | \(stats.winsA) |")
        lines.append("| \(markdownCell(b.name)) | **\(percent(1 - stats.scoreA))** | \(stats.winsB) |")
        lines.append("")
        if stats.draws > 0 { lines.append("Égalités : \(stats.draws).") }
        lines.append("Fins de partie : \(markdownCell(endings(stats))).")
        return lines.joined(separator: "\n") + "\n"
    }
}
