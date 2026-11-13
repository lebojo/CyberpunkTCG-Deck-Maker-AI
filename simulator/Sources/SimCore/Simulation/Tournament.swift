import Foundation

public struct TournamentStats: Sendable {
    public internal(set) var tournaments = 0
    public internal(set) var titles: [Int]
    public internal(set) var finals: [Int]
    public internal(set) var matchesPlayed: [Int]
    public internal(set) var matchesWon: [Int]
    public internal(set) var gamesPlayed: [Int]
    public internal(set) var gamesWon: [Int]

    init(deckCount: Int) {
        titles = Array(repeating: 0, count: deckCount)
        finals = Array(repeating: 0, count: deckCount)
        matchesPlayed = Array(repeating: 0, count: deckCount)
        matchesWon = Array(repeating: 0, count: deckCount)
        gamesPlayed = Array(repeating: 0, count: deckCount)
        gamesWon = Array(repeating: 0, count: deckCount)
    }

    mutating func merge(_ other: TournamentStats) {
        tournaments += other.tournaments
        for index in titles.indices {
            titles[index] += other.titles[index]
            finals[index] += other.finals[index]
            matchesPlayed[index] += other.matchesPlayed[index]
            matchesWon[index] += other.matchesWon[index]
            gamesPlayed[index] += other.gamesPlayed[index]
            gamesWon[index] += other.gamesWon[index]
        }
    }
}

public enum Tournament {
    public static func run(catalog: CardCatalog, decks: [DeckList], count: Int, bestOf: Int, seed: UInt64, workers: Int, search: Bool, config: SearchConfig = SearchConfig(), progress: ProgressTracker? = nil) async -> TournamentStats {
        let chunk = max(1, count / (workers * 4))
        return await withTaskGroup(of: TournamentStats.self) { group in
            var start = 0
            while start < count {
                let range = start..<min(count, start + chunk)
                group.addTask {
                    let local = catalog.isolatedCopy()
                    var stats = TournamentStats(deckCount: decks.count)
                    for index in range {
                        playOne(catalog: local, decks: decks, bestOf: bestOf, search: search, config: config, seed: seed &+ UInt64(index) &* 0xD1B5_4A32_D192_ED03, progress: progress, into: &stats)
                    }
                    return stats
                }
                start += chunk
            }
            var total = TournamentStats(deckCount: decks.count)
            for await part in group { total.merge(part) }
            return total
        }
    }

    static func playOne(catalog: CardCatalog, decks: [DeckList], bestOf: Int, search: Bool, config: SearchConfig, seed: UInt64, progress: ProgressTracker? = nil, into stats: inout TournamentStats) {
        var rng = SplitMix64(seed: seed)
        var remaining = Array(decks.indices)
        remaining.shuffle(using: &rng)
        stats.tournaments += 1
        while remaining.count > 1 {
            var next: [Int] = []
            var index = 0
            while index < remaining.count {
                guard index + 1 < remaining.count else {
                    next.append(remaining[index])
                    break
                }
                let a = remaining[index]
                let b = remaining[index + 1]
                let isFinal = remaining.count == 2
                let before = (stats.gamesPlayed[a], stats.gamesWon[a], stats.gamesWon[b])
                let winner = playMatch(catalog: catalog, decks: decks, a: a, b: b, bestOf: bestOf, search: search, config: config, rng: &rng, stats: &stats)
                progress?.recordMatch(a: a, b: b, winner: winner, games: GameBatch(games: stats.gamesPlayed[a] - before.0, winsA: stats.gamesWon[a] - before.1, winsB: stats.gamesWon[b] - before.2))
                stats.matchesPlayed[a] += 1
                stats.matchesPlayed[b] += 1
                stats.matchesWon[winner] += 1
                if isFinal {
                    stats.finals[a] += 1
                    stats.finals[b] += 1
                    stats.titles[winner] += 1
                }
                next.append(winner)
                index += 2
            }
            remaining = next
        }
        progress?.finishTournament(champion: remaining[0])
    }

    static func playMatch(catalog: CardCatalog, decks: [DeckList], a: Int, b: Int, bestOf: Int, search: Bool, config: SearchConfig, rng: inout SplitMix64, stats: inout TournamentStats) -> Int {
        let target = bestOf / 2 + 1
        var winsA = 0
        var winsB = 0
        var played = 0
        while winsA < target && winsB < target {
            played += 1
            let gameSeed = rng.next()
            let first = Int.random(in: 0...1, using: &rng)
            let result = Simulator.winner(catalog: catalog, decks: [decks[a], decks[b]], seed: gameSeed, firstPlayer: first, search: [search, search], config: config)
            stats.gamesPlayed[a] += 1
            stats.gamesPlayed[b] += 1
            switch result {
            case 0:
                winsA += 1
                stats.gamesWon[a] += 1
            case 1:
                winsB += 1
                stats.gamesWon[b] += 1
            default:
                break
            }
            if played > 30 { return Bool.random(using: &rng) ? a : b }
        }
        return winsA > winsB ? a : b
    }
}
