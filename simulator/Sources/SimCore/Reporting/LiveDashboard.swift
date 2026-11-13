import Foundation

public enum LiveDashboard {
    struct Column {
        let header: String
        let priority: Int
        let value: (DeckProgress) -> String
    }

    public static func duration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 { return String(format: "%dh%02dm", hours, minutes) }
        if minutes > 0 { return String(format: "%dm%02ds", minutes, secs) }
        return "\(secs)s"
    }

    public static func etaText(_ snapshot: ProgressSnapshot) -> String {
        guard let eta = snapshot.etaSeconds else { return "--" }
        return "~" + duration(eta)
    }

    public static func percentText(_ fraction: Double) -> String {
        String(format: "%5.1f%%", fraction * 100)
    }

    public static func progressBar(fraction: Double, width: Int) -> String {
        let cells = max(1, width - 2)
        let filled = Int((min(1, max(0, fraction)) * Double(cells)).rounded(.down))
        return "[" + String(repeating: "█", count: filled) + String(repeating: "░", count: cells - filled) + "]"
    }

    public static func truncate(_ text: String, _ width: Int) -> String {
        guard width > 0 else { return "" }
        guard text.count > width else { return text }
        guard width > 1 else { return String(text.prefix(1)) }
        return String(text.prefix(width - 1)) + "…"
    }

    static func padLeft(_ text: String, _ width: Int) -> String {
        text.count >= width ? text : String(repeating: " ", count: width - text.count) + text
    }

    static func unitLabel(_ mode: ProgressMode) -> String {
        switch mode {
        case .duel: return "parties"
        case .matrix: return "duels"
        case .tournament: return "tournois"
        }
    }

    static func titleLine(_ snapshot: ProgressSnapshot) -> String {
        switch snapshot.mode {
        case .duel: return "DeckSim : duel en cours"
        case .matrix: return "DeckSim : matrice de duels en cours"
        case .tournament: return "DeckSim : tournois en cours"
        }
    }

    public static func rankedIndices(_ snapshot: ProgressSnapshot) -> [Int] {
        let decks = snapshot.decks
        return decks.indices.sorted { left, right in
            let a = decks[left]
            let b = decks[right]
            if case .tournament = snapshot.mode {
                if a.titles != b.titles { return a.titles > b.titles }
                if a.matchWinRate != b.matchWinRate { return a.matchWinRate > b.matchWinRate }
            }
            if a.gameWinRate != b.gameWinRate { return a.gameWinRate > b.gameWinRate }
            return left < right
        }
    }

    static func columns(_ snapshot: ProgressSnapshot) -> [Column] {
        let games = Column(header: "WR parties", priority: 1) { Report.percent($0.gameWinRate) }
        switch snapshot.mode {
        case .duel:
            return [
                Column(header: "Parties", priority: 2) { String($0.gamesPlayed) },
                Column(header: "Victoires", priority: 3) { String($0.gamesWon) },
                games,
            ]
        case .matrix:
            return [
                Column(header: "Duels", priority: 2) { String($0.matchesPlayed) },
                Column(header: "Gagnés", priority: 3) { String($0.matchesWon) },
                Column(header: "WR duels", priority: 4) { Report.percent($0.matchWinRate) },
                games,
            ]
        case .tournament:
            let done = Double(max(1, snapshot.completedUnits))
            return [
                Column(header: "Tournois", priority: 2) { String($0.titles) },
                Column(header: "%", priority: 3) { Report.percent(Double($0.titles) / done) },
                Column(header: "Matchs", priority: 6) { String($0.matchesPlayed) },
                Column(header: "Gagnés", priority: 5) { String($0.matchesWon) },
                Column(header: "WR matchs", priority: 4) { Report.percent($0.matchWinRate) },
                games,
            ]
        }
    }

    static func columnWidth(_ column: Column, _ snapshot: ProgressSnapshot) -> Int {
        max(column.header.count, snapshot.decks.map { column.value($0).count }.max() ?? 0)
    }

    public static func tableLines(_ snapshot: ProgressSnapshot, width: Int) -> [String] {
        let all = columns(snapshot)
        let minimumName = 10
        let rankWidth = 4
        func fixed(_ kept: [Column]) -> Int {
            rankWidth + kept.reduce(0) { $0 + columnWidth($1, snapshot) + 1 }
        }
        var limit = all.map(\.priority).max() ?? 0
        while limit > 1 && minimumName + fixed(all.filter { $0.priority <= limit }) > width - 1 { limit -= 1 }
        let kept = all.filter { $0.priority <= limit }
        let longest = snapshot.deckNames.map(\.count).max() ?? 0
        let nameWidth = max(4, min(longest, 32, width - 1 - fixed(kept)))
        let widths = kept.map { columnWidth($0, snapshot) }
        var lines: [String] = []
        var header = Report.pad("", rankWidth) + Report.pad("Deck", nameWidth)
        for (column, columnWidth) in zip(kept, widths) { header += " " + padLeft(column.header, columnWidth) }
        lines.append(header)
        for (rank, index) in rankedIndices(snapshot).enumerated() {
            var line = Report.pad("\(rank + 1).", rankWidth) + Report.pad(truncate(snapshot.deckNames[index], nameWidth), nameWidth)
            for (column, columnWidth) in zip(kept, widths) { line += " " + padLeft(column.value(snapshot.decks[index]), columnWidth) }
            lines.append(line)
        }
        return lines
    }

    static func summaryLines(_ snapshot: ProgressSnapshot, width: Int) -> [String] {
        let counter = "\(snapshot.completedUnits)/\(snapshot.totalUnits) \(unitLabel(snapshot.mode))"
        let suffix = " " + percentText(snapshot.fraction) + "  " + counter
        let barWidth = max(7, min(40, width - 1 - suffix.count))
        var lines = [progressBar(fraction: snapshot.fraction, width: barWidth) + suffix]
        let rate = String(format: "%.1f", snapshot.gamesPerSecond)
        lines.append("écoulé \(duration(snapshot.elapsed))  reste \(etaText(snapshot))  \(rate) parties/s")
        lines.append(contentsOf: detailLines(snapshot))
        return lines
    }

    static func detailLines(_ snapshot: ProgressSnapshot) -> [String] {
        switch snapshot.mode {
        case .duel:
            guard snapshot.decks.count >= 2, snapshot.gamesDone > 0 else { return ["win rate de \(snapshot.deckNames[0]) : --"] }
            let games = Double(snapshot.gamesDone)
            let draws = games - Double(snapshot.decks[0].gamesWon + snapshot.decks[1].gamesWon)
            let score = (Double(snapshot.decks[0].gamesWon) + 0.5 * draws) / games
            let margin = 1.96 * (score * (1 - score) / games).squareRoot()
            return ["win rate de \(snapshot.deckNames[0]) : \(Report.percent(score)) ±\(Report.percent(margin))"]
        case .matrix:
            guard let pair = snapshot.currentDuel, pair.count == 2 else { return [] }
            return ["duel en cours : \(snapshot.deckNames[pair[0]])  vs  \(snapshot.deckNames[pair[1]])  (\(snapshot.currentDuelGames) parties)"]
        case .tournament:
            return []
        }
    }

    public static func lines(_ snapshot: ProgressSnapshot, width: Int) -> [String] {
        let usable = max(20, width)
        var lines = [titleLine(snapshot)]
        lines.append(contentsOf: summaryLines(snapshot, width: usable))
        lines.append("")
        lines.append(contentsOf: tableLines(snapshot, width: usable))
        return lines.map { truncate($0, usable - 1) }
    }

    public static func statusLine(_ snapshot: ProgressSnapshot) -> String {
        var line = "[\(percentText(snapshot.fraction).trimmingCharacters(in: .whitespaces))] écoulé \(duration(snapshot.elapsed)), reste \(etaText(snapshot)), \(String(format: "%.1f", snapshot.gamesPerSecond)) parties/s"
        if let best = rankedIndices(snapshot).first, snapshot.gamesDone > 0 {
            line += ", en tête : \(snapshot.deckNames[best]) (\(bestMetric(snapshot, best)))"
        }
        return line
    }

    static func bestMetric(_ snapshot: ProgressSnapshot, _ index: Int) -> String {
        let deck = snapshot.decks[index]
        if case .tournament = snapshot.mode {
            return "\(deck.titles) tournois gagnés"
        }
        return "win rate \(Report.percent(deck.gameWinRate))"
    }
}
