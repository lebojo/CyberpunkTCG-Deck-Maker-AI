import Foundation
import SimCore

struct Options {
    var deckPaths: [String] = []
    var games = 2000
    var seed: UInt64 = 42
    var trace = false
    var tournaments = 0
    var search = true
    var versus = false
    var bestOf = 3
    var markdownPath: String?
    var samples = 3
    var depth = 3
    var shortlist = 4
    var workers = ProcessInfo.processInfo.activeProcessorCount
    var coverage = false
    var live = true
    var bluff = SearchConfig.defaultBluff
    var opponentBudget = SearchConfig().opponentBudget
    var oldSeats = OldSeats.none
    var bluffSeats = BluffSeats.both

    var searchConfig: SearchConfig {
        SearchConfig(samples: samples, depth: depth, shortlist: shortlist, opponentBudget: opponentBudget, bluff: bluff)
    }

    var policy: Policy { Policy(search: search, config: searchConfig) }

    var seatPolicies: [Policy] {
        var seats = versus ? [policy, Policy(search: false, config: searchConfig)] : [policy, policy]
        if bluffSeats == .firstOnly {
            seats[0].config.bluff = true
            seats[1].config.bluff = false
        }
        switch oldSeats {
        case .none: break
        case .second: seats[1] = seats[1].legacy
        case .both: seats = seats.map(\.legacy)
        }
        return seats
    }
}

enum OldSeats {
    case none
    case second
    case both
}

enum BluffSeats {
    case both
    case firstOnly
}

enum CLIError: Error, CustomStringConvertible {
    case usage(String)

    var description: String {
        switch self {
        case .usage(let message): return message
        }
    }
}

enum OptionParser {
    static let usage = """
    Usage : DeckSim <deck1.txt> <deck2.txt> [deck3.txt ...] [--games N] [--seed S] [--workers N] [--trace]
      2 decks  : duel détaillé
      3+ decks : matrice de tous les duels + classement
      --tournaments N [--bo 3] : N tournois à élimination directe, ordre de départ aléatoire, classés par titres gagnés
      --ai search|greedy|versus : IA qui explore ses coups (défaut), heuristique rapide, ou 1er deck en recherche contre 2e en heuristique
      --samples N --depth N --shortlist N : mains adverses tirées par décision, tours projetés, coups approfondis (3, 3, 4)
      --md fichier.md : écrit aussi le tableau de résultats au format Markdown
      --trace  : affiche le déroulé d'une seule partie
      --coverage : liste les cartes qui ont un effet codé et celles qui restent à coder (aucun deck nécessaire)
      --no-live : désactive l'affichage en direct
      --bluff on|off : active ou non le bluff de l'IA (finir son tour en gardant du mana et des Units prêtes)
      --opponent-budget N : décisions cherchées par tour adverse simulé dans la recherche (0 = adversaire glouton, défaut 1)
      --ai-old b|all : outil de dev, l'ancienne IA (avant bluff, défense et adversaire simulé) joue le 2e deck (b) ou les deux (all)
      --bluff-ab : outil de dev, bluff activé pour le 1er deck seulement (test A/B)
    """

    static func parse(_ arguments: [String]) throws -> Options {
        var options = Options()
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--games": options.games = try positive(iterator.next(), "--games")
            case "--seed":
                guard let value = iterator.next(), let seed = UInt64(value) else { throw CLIError.usage("--seed attend un entier") }
                options.seed = seed
            case "--workers": options.workers = try positive(iterator.next(), "--workers")
            case "--tournaments": options.tournaments = try positive(iterator.next(), "--tournaments")
            case "--bo":
                guard let value = iterator.next(), let bestOf = Int(value), bestOf > 0, bestOf % 2 == 1 else { throw CLIError.usage("--bo attend un entier impair (1, 3, 5)") }
                options.bestOf = bestOf
            case "--ai":
                guard let value = iterator.next(), ["search", "greedy", "versus"].contains(value) else { throw CLIError.usage("--ai attend search, greedy ou versus") }
                options.search = value != "greedy"
                options.versus = value == "versus"
            case "--md":
                guard let value = iterator.next() else { throw CLIError.usage("--md attend un chemin de fichier .md") }
                options.markdownPath = NSString(string: value).expandingTildeInPath
            case "--samples": options.samples = try positive(iterator.next(), "--samples")
            case "--depth": options.depth = try positive(iterator.next(), "--depth")
            case "--shortlist": options.shortlist = try positive(iterator.next(), "--shortlist")
            case "--trace": options.trace = true
            case "--coverage": options.coverage = true
            case "--no-live": options.live = false
            case "--bluff":
                guard let value = iterator.next(), ["on", "off"].contains(value) else { throw CLIError.usage("--bluff attend on ou off") }
                options.bluff = value == "on"
            case "--opponent-budget":
                guard let value = iterator.next(), let budget = Int(value), budget >= 0 else { throw CLIError.usage("--opponent-budget attend un entier positif ou nul") }
                options.opponentBudget = budget
            case "--ai-old":
                guard let value = iterator.next(), ["b", "all"].contains(value) else { throw CLIError.usage("--ai-old attend b ou all") }
                options.oldSeats = value == "b" ? .second : .both
            case "--bluff-ab": options.bluffSeats = .firstOnly
            case "--cards":
                throw CLIError.usage("--cards n'existe plus : la base de cartes est embarquée (lancer FetchCards pour la mettre à jour)")
            default:
                options.deckPaths.append(argument)
            }
        }
        guard options.coverage || options.deckPaths.count >= 2 else { throw CLIError.usage(usage) }
        return options
    }

    static func positive(_ value: String?, _ name: String) throws -> Int {
        guard let value, let number = Int(value), number > 0 else { throw CLIError.usage("\(name) attend un entier positif") }
        return number
    }
}
