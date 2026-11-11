import Foundation

struct Options {
    var deckPaths: [String] = []
    var games = 2000
    var seed: UInt64 = 42
    var trace = false
    var cardsPath = NSString(string: "~/.cache/cyberpunk-deck-sim/cards.json").expandingTildeInPath
    var tournaments = 0
    var search = true
    var versus = false
    var bestOf = 3
    var samples = 3
    var depth = 3
    var shortlist = 4
    var workers = ProcessInfo.processInfo.activeProcessorCount
}

enum CLIError: Error, CustomStringConvertible {
    case usage(String)

    var description: String {
        switch self {
        case .usage(let message): return message
        }
    }
}

func parseOptions(_ arguments: [String]) throws -> Options {
    var options = Options()
    var iterator = arguments.makeIterator()
    while let argument = iterator.next() {
        switch argument {
        case "--games":
            guard let value = iterator.next(), let games = Int(value), games > 0 else { throw CLIError.usage("--games attend un entier positif") }
            options.games = games
        case "--seed":
            guard let value = iterator.next(), let seed = UInt64(value) else { throw CLIError.usage("--seed attend un entier") }
            options.seed = seed
        case "--cards":
            guard let value = iterator.next() else { throw CLIError.usage("--cards attend un chemin") }
            options.cardsPath = value
        case "--workers":
            guard let value = iterator.next(), let workers = Int(value), workers > 0 else { throw CLIError.usage("--workers attend un entier positif") }
            options.workers = workers
        case "--tournaments":
            guard let value = iterator.next(), let count = Int(value), count > 0 else { throw CLIError.usage("--tournaments attend un entier positif") }
            options.tournaments = count
        case "--bo":
            guard let value = iterator.next(), let bestOf = Int(value), bestOf > 0, bestOf % 2 == 1 else { throw CLIError.usage("--bo attend un entier impair (1, 3, 5)") }
            options.bestOf = bestOf
        case "--ai":
            guard let value = iterator.next(), ["search", "greedy", "versus"].contains(value) else { throw CLIError.usage("--ai attend search, greedy ou versus") }
            options.search = value != "greedy"
            options.versus = value == "versus"
        case "--samples":
            guard let value = iterator.next(), let samples = Int(value), samples > 0 else { throw CLIError.usage("--samples attend un entier positif") }
            options.samples = samples
        case "--depth":
            guard let value = iterator.next(), let depth = Int(value), depth > 0 else { throw CLIError.usage("--depth attend un entier positif") }
            options.depth = depth
        case "--shortlist":
            guard let value = iterator.next(), let shortlist = Int(value), shortlist > 0 else { throw CLIError.usage("--shortlist attend un entier positif") }
            options.shortlist = shortlist
        case "--trace":
            options.trace = true
        default:
            options.deckPaths.append(argument)
        }
    }
    guard options.deckPaths.count >= 2 else {
        throw CLIError.usage("""
        Usage : DeckSim <deck1.txt> <deck2.txt> [deck3.txt ...] [--games N] [--seed S] [--workers N] [--trace] [--cards cards.json]
          2 decks  : duel détaillé
          3+ decks : matrice de tous les duels + classement
          --tournaments N [--bo 3] : N tournois à élimination directe, ordre de départ aléatoire, classés par titres gagnés
          --ai search|greedy|versus : IA qui explore ses coups (défaut), heuristique rapide, ou 1er deck en recherche contre 2e en heuristique
          --samples N --depth N --shortlist N : mains adverses tirées par décision, tours projetés, coups approfondis (3, 3, 4)
          --trace  : affiche le déroulé d'une seule partie
        """)
    }
    return options
}

func run() async throws {
    let options = try parseOptions(Array(CommandLine.arguments.dropFirst()))
    Game.searchConfig = SearchConfig(samples: options.samples, depth: options.depth, shortlist: options.shortlist)
    let catalog = try await CardCatalog.load(cachePath: options.cardsPath)
    let decks = try options.deckPaths.map { try DeckList.load(path: $0, catalog: catalog) }
    for deck in decks where !deck.problems.isEmpty {
        print("Attention, \(deck.name) : " + deck.problems.joined(separator: "; "))
    }
    let unsupported = Report.unsupportedCards(decks: decks, catalog: catalog)
    if !unsupported.isEmpty {
        print("Cartes sans effet implémenté (jouées comme des cartes sans texte) : " + unsupported.joined(separator: ", "))
    }

    if options.trace {
        let result = Simulator.playOne(catalog: catalog, decks: Array(decks.prefix(2)), index: 0, seed: options.seed, search: options.versus ? [true, false] : [options.search, options.search], tracing: true)
        print(result.trace.joined(separator: "\n"))
        print("\nRésultat : \(result.summary.winner.map { "victoire de \(decks[$0].name)" } ?? "égalité") en \(result.summary.turns) tours")
        return
    }

    let start = Date()
    if options.tournaments > 0 {
        let stats = await Tournament.run(catalog: catalog, decks: decks, count: options.tournaments, bestOf: options.bestOf, seed: options.seed, workers: options.workers, search: options.search)
        print(Report.tournament(decks: decks, stats: stats, bestOf: options.bestOf))
    } else if decks.count == 2 {
        let stats = await Simulator.duel(catalog: catalog, a: decks[0], b: decks[1], games: options.games, seed: options.seed, workers: options.workers, search: options.versus ? [true, false] : [options.search, options.search])
        print(Report.duel(a: decks[0], b: decks[1], stats: stats))
    } else {
        var scores = Array(repeating: Array<Double?>(repeating: nil, count: decks.count), count: decks.count)
        for i in decks.indices {
            for j in decks.indices where i < j {
                let stats = await Simulator.duel(catalog: catalog, a: decks[i], b: decks[j], games: options.games, seed: options.seed, workers: options.workers, search: [options.search, options.search])
                scores[i][j] = stats.scoreA
                scores[j][i] = 1 - stats.scoreA
            }
        }
        print(Report.matrix(decks: decks, scores: scores))
    }
    print(String(format: "\n(%.1f s)", Date().timeIntervalSince(start)))
}

do {
    try await run()
} catch {
    print(error)
    exit(1)
}
