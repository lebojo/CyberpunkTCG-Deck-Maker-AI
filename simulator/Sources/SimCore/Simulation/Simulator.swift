import Foundation

public struct GameSummary: Sendable {
    public let winner: Int?
    public let reason: WinReason?
    public let turns: Int
    public let firstPlayer: Int
    public let mulligans: [Bool]
}

public struct DuelStats: Sendable {
    public internal(set) var games = 0
    public internal(set) var winsA = 0
    public internal(set) var winsB = 0
    public internal(set) var draws = 0
    public internal(set) var winsAWhenFirst = 0
    public internal(set) var gamesAWhenFirst = 0
    public internal(set) var winsAWhenSecond = 0
    public internal(set) var gamesAWhenSecond = 0
    public internal(set) var turnSum = 0
    public internal(set) var reasons: [String: Int] = [:]
    public internal(set) var mulligansA = 0
    public internal(set) var mulligansB = 0

    public init() {}

    mutating func add(_ summary: GameSummary) {
        games += 1
        turnSum += summary.turns
        if summary.mulligans[0] { mulligansA += 1 }
        if summary.mulligans[1] { mulligansB += 1 }
        let aFirst = summary.firstPlayer == 0
        if aFirst { gamesAWhenFirst += 1 } else { gamesAWhenSecond += 1 }
        switch summary.winner {
        case 0:
            winsA += 1
            if aFirst { winsAWhenFirst += 1 } else { winsAWhenSecond += 1 }
        case 1:
            winsB += 1
        default:
            draws += 1
        }
        if let reason = summary.reason { reasons[Self.label(reason), default: 0] += 1 }
    }

    mutating func merge(_ other: DuelStats) {
        games += other.games
        winsA += other.winsA
        winsB += other.winsB
        draws += other.draws
        winsAWhenFirst += other.winsAWhenFirst
        gamesAWhenFirst += other.gamesAWhenFirst
        winsAWhenSecond += other.winsAWhenSecond
        gamesAWhenSecond += other.gamesAWhenSecond
        turnSum += other.turnSum
        mulligansA += other.mulligansA
        mulligansB += other.mulligansB
        for (key, value) in other.reasons { reasons[key, default: 0] += value }
    }

    static func label(_ reason: WinReason) -> String {
        switch reason {
        case .gigsAtStart: return "7 Gigs au début du tour"
        case .gigsInOvertime: return "7 Gigs en Overtime"
        case .deckOut: return "pioche vide"
        case .turnLimit: return "limite de tours"
        }
    }

    public var scoreA: Double { games == 0 ? 0 : (Double(winsA) + 0.5 * Double(draws)) / Double(games) }

    public var confidenceMargin: Double {
        guard games > 0 else { return 0 }
        let n = Double(games)
        let p = scoreA
        return 1.96 * (p * (1 - p) / n).squareRoot()
    }
}

public enum Simulator {
    public static func playOne(catalog: CardCatalog, decks: [DeckList], index: Int, seed: UInt64, search: [Bool], config: SearchConfig = SearchConfig(), tracing: Bool = false) -> (summary: GameSummary, trace: [String]) {
        let gameSeed = seed &+ UInt64(index) &* 0x9E37_79B9_7F4A_7C15
        let first = index % 2
        var game = Game(catalog: catalog, decks: decks, seed: gameSeed, firstPlayer: first, tracing: tracing, search: search, config: config)
        game.playGame()
        let summary: GameSummary
        switch game.outcome {
        case .win(let player, let reason):
            summary = GameSummary(winner: player, reason: reason, turns: game.turn, firstPlayer: first, mulligans: game.players.map { $0.mulliganed })
        default:
            summary = GameSummary(winner: nil, reason: nil, turns: game.turn, firstPlayer: first, mulligans: game.players.map { $0.mulliganed })
        }
        return (summary, game.traceLines)
    }

    public static func winner(catalog: CardCatalog, decks: [DeckList], seed: UInt64, firstPlayer: Int, search: [Bool], config: SearchConfig = SearchConfig()) -> Int? {
        var game = Game(catalog: catalog, decks: decks, seed: seed, firstPlayer: firstPlayer, tracing: false, search: search, config: config)
        game.playGame()
        if case .win(let player, _) = game.outcome { return player }
        return nil
    }

    public static func duel(catalog: CardCatalog, a: DeckList, b: DeckList, games: Int, seed: UInt64, workers: Int, search: [Bool], config: SearchConfig = SearchConfig(), progress: DuelProgress? = nil) async -> DuelStats {
        let chunk = max(1, games / (workers * 4))
        return await withTaskGroup(of: DuelStats.self) { group in
            var start = 0
            while start < games {
                let range = start..<min(games, start + chunk)
                group.addTask {
                    let local = catalog.isolatedCopy()
                    var stats = DuelStats()
                    var batch = GameBatch()
                    for index in range {
                        let summary = playOne(catalog: local, decks: [a, b], index: index, seed: seed, search: search, config: config).summary
                        stats.add(summary)
                        batch.add(winner: summary.winner)
                        if batch.games >= 16 {
                            progress?.publish(batch)
                            batch = GameBatch()
                        }
                    }
                    progress?.publish(batch)
                    return stats
                }
                start += chunk
            }
            var total = DuelStats()
            for await part in group { total.merge(part) }
            return total
        }
    }
}
