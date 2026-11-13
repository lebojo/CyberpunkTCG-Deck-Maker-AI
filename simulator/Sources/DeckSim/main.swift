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
    let config = options.searchConfig
    let both = options.versus ? [true, false] : [options.search, options.search]

    if options.trace {
        let result = Simulator.playOne(catalog: catalog, decks: Array(decks.prefix(2)), index: 0, seed: options.seed, search: both, config: config, tracing: true)
        print(result.trace.joined(separator: "\n"))
        print("\nRésultat : \(result.summary.winner.map { "victoire de \(decks[$0].name)" } ?? "égalité") en \(result.summary.turns) tours")
        return
    }

    let start = Date()
    if options.tournaments > 0 {
        let stats = await Tournament.run(catalog: catalog, decks: decks, count: options.tournaments, bestOf: options.bestOf, seed: options.seed, workers: options.workers, search: options.search, config: config)
        print(Report.tournament(decks: decks, stats: stats, bestOf: options.bestOf))
        writeMarkdown(Report.tournamentMarkdown(decks: decks, stats: stats, bestOf: options.bestOf), to: options.markdownPath)
    } else if decks.count == 2 {
        let stats = await Simulator.duel(catalog: catalog, a: decks[0], b: decks[1], games: options.games, seed: options.seed, workers: options.workers, search: both, config: config)
        print(Report.duel(a: decks[0], b: decks[1], stats: stats))
        writeMarkdown(Report.duelMarkdown(a: decks[0], b: decks[1], stats: stats), to: options.markdownPath)
    } else {
        var scores = Array(repeating: Array<Double?>(repeating: nil, count: decks.count), count: decks.count)
        for i in decks.indices {
            for j in decks.indices where i < j {
                let stats = await Simulator.duel(catalog: catalog, a: decks[i], b: decks[j], games: options.games, seed: options.seed, workers: options.workers, search: [options.search, options.search], config: config)
                scores[i][j] = stats.scoreA
                scores[j][i] = 1 - stats.scoreA
            }
        }
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
