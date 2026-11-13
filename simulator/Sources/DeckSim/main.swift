import Foundation
import SimCore

func writeMarkdown(_ content: String, to path: String?) {
    guard let path else { return }
    do {
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        print("\nTableau Markdown écrit dans \(path)")
    } catch {
        print("Impossible d'écrire \(path) : \(error)")
    }
}

func run() async throws {
    let options = try OptionParser.parse(Array(CommandLine.arguments.dropFirst()))
    let catalog = try CardCatalog.embedded()
    if options.coverage {
        print(CoverageReport.text(catalog))
        if options.deckPaths.isEmpty { return }
        print("")
    }
    let decks = try options.deckPaths.map { try DeckList.load(path: $0, catalog: catalog) }
    for deck in decks where !deck.problems.isEmpty {
        print("Attention, \(deck.name) : " + deck.problems.joined(separator: "; "))
    }
    let missing = CoverageReport.missingCards(in: decks, catalog: catalog)
    if !missing.isEmpty {
        print("Cartes sans effet implémenté (jouées comme des cartes sans texte) : " + missing.joined(separator: ", "))
    }
    guard decks.count >= 2 else { return }
    let seats = options.seatPolicies

    if options.trace {
        let result = Simulator.playOne(catalog: catalog, decks: Array(decks.prefix(2)), index: 0, seed: options.seed, policies: seats, tracing: true)
        print(result.trace.joined(separator: "\n"))
        print("\nRésultat : \(result.summary.winner.map { "victoire de \(decks[$0].name)" } ?? "égalité") en \(result.summary.turns) tours")
        return
    }

    let start = Date()
    let names = decks.map(\.name)
    if options.tournaments > 0 {
        let tracker = ProgressTracker(mode: .tournament(count: options.tournaments), deckNames: names)
        let live = options.live ? LiveDisplay.start(tracker: tracker) : nil
        let stats = await Tournament.run(catalog: catalog, decks: decks, count: options.tournaments, bestOf: options.bestOf, seed: options.seed, workers: options.workers, policies: seats, progress: tracker)
        live?.stop()
        print(Report.tournament(decks: decks, stats: stats, bestOf: options.bestOf))
        writeMarkdown(Report.tournamentMarkdown(decks: decks, stats: stats, bestOf: options.bestOf), to: options.markdownPath)
    } else if decks.count == 2 {
        let tracker = ProgressTracker(mode: .duel(games: options.games), deckNames: names)
        let live = options.live ? LiveDisplay.start(tracker: tracker) : nil
        let stats = await Simulator.duel(catalog: catalog, a: decks[0], b: decks[1], games: options.games, seed: options.seed, workers: options.workers, policies: seats, progress: DuelProgress(tracker: tracker, a: 0, b: 1))
        live?.stop()
        print(Report.duel(a: decks[0], b: decks[1], stats: stats))
        writeMarkdown(Report.duelMarkdown(a: decks[0], b: decks[1], stats: stats), to: options.markdownPath)
    } else {
        let tracker = ProgressTracker(mode: .matrix(duels: decks.count * (decks.count - 1) / 2, gamesPerDuel: options.games), deckNames: names)
        let live = options.live ? LiveDisplay.start(tracker: tracker) : nil
        var scores = Array(repeating: Array<Double?>(repeating: nil, count: decks.count), count: decks.count)
        for i in decks.indices {
            for j in decks.indices where i < j {
                tracker.beginDuel(a: i, b: j)
                let stats = await Simulator.duel(catalog: catalog, a: decks[i], b: decks[j], games: options.games, seed: options.seed, workers: options.workers, policies: seats, progress: DuelProgress(tracker: tracker, a: i, b: j))
                tracker.finishDuel(a: i, b: j, scoreA: stats.scoreA)
                scores[i][j] = stats.scoreA
                scores[j][i] = 1 - stats.scoreA
            }
        }
        live?.stop()
        print(Report.matrix(decks: decks, scores: scores))
        writeMarkdown(Report.matrixMarkdown(decks: decks, scores: scores), to: options.markdownPath)
    }
    print(String(format: "\n(%.1f s)", Date().timeIntervalSince(start)))
}

do {
    try await run()
} catch {
    print(error)
    exit(1)
}
