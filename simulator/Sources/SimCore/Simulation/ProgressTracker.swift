import Foundation
import os

public enum ProgressMode: Sendable, Equatable {
    case duel(games: Int)
    case matrix(duels: Int, gamesPerDuel: Int)
    case tournament(count: Int)

    var totalUnits: Int {
        switch self {
        case .duel(let games): return games
        case .matrix(let duels, _): return duels
        case .tournament(let count): return count
        }
    }
}

public struct DeckProgress: Sendable, Equatable {
    public var matchesPlayed = 0
    public var matchesWon = 0
    public var matchesDrawn = 0
    public var gamesPlayed = 0
    public var gamesWon = 0
    public var titles = 0

    public init() {}

    public var matchPoints: Double { Double(matchesWon) + 0.5 * Double(matchesDrawn) }
    public var matchWinRate: Double { matchesPlayed == 0 ? 0 : matchPoints / Double(matchesPlayed) }
    public var gameWinRate: Double { gamesPlayed == 0 ? 0 : Double(gamesWon) / Double(gamesPlayed) }
}

public struct GameBatch: Sendable, Equatable {
    public private(set) var games = 0
    public private(set) var winsA = 0
    public private(set) var winsB = 0

    public init() {}

    public init(games: Int, winsA: Int, winsB: Int) {
        self.games = games
        self.winsA = winsA
        self.winsB = winsB
    }

    public mutating func add(winner: Int?) {
        games += 1
        if winner == 0 { winsA += 1 }
        if winner == 1 { winsB += 1 }
    }
}

public struct DuelProgress: Sendable {
    let tracker: ProgressTracker
    let a: Int
    let b: Int

    public init(tracker: ProgressTracker, a: Int, b: Int) {
        self.tracker = tracker
        self.a = a
        self.b = b
    }

    func publish(_ batch: GameBatch) {
        tracker.publishDuel(a: a, b: b, batch: batch)
    }
}

public struct ProgressSnapshot: Sendable, Equatable {
    public var mode: ProgressMode
    public var deckNames: [String]
    public var decks: [DeckProgress]
    public var elapsed: Double
    public var gamesDone: Int
    public var completedUnits: Int
    public var currentDuel: [Int]?
    public var currentDuelGames: Int

    public init(mode: ProgressMode, deckNames: [String], decks: [DeckProgress], elapsed: Double, gamesDone: Int, completedUnits: Int, currentDuel: [Int]? = nil, currentDuelGames: Int = 0) {
        self.mode = mode
        self.deckNames = deckNames
        self.decks = decks
        self.elapsed = elapsed
        self.gamesDone = gamesDone
        self.completedUnits = completedUnits
        self.currentDuel = currentDuel
        self.currentDuelGames = currentDuelGames
    }

    public var totalUnits: Int { mode.totalUnits }

    public var fraction: Double {
        guard totalUnits > 0 else { return 1 }
        return min(1, (Double(completedUnits) + currentDuelFraction) / Double(totalUnits))
    }

    var currentDuelFraction: Double {
        guard case .matrix(_, let gamesPerDuel) = mode, currentDuel != nil, gamesPerDuel > 0 else { return 0 }
        return min(1, Double(currentDuelGames) / Double(gamesPerDuel))
    }

    public var gamesPerSecond: Double { elapsed > 0 ? Double(gamesDone) / elapsed : 0 }

    public var etaSeconds: Double? {
        guard fraction > 0 else { return nil }
        return elapsed * (1 - fraction) / fraction
    }
}

public final class ProgressTracker: Sendable {
    private struct State {
        var decks: [DeckProgress]
        var gamesDone = 0
        var completedUnits = 0
        var currentDuel: [Int]?
        var currentDuelGames = 0
    }

    public let mode: ProgressMode
    public let deckNames: [String]
    private let startedAt = Date()
    private let state: OSAllocatedUnfairLock<State>

    public init(mode: ProgressMode, deckNames: [String]) {
        self.mode = mode
        self.deckNames = deckNames
        self.state = OSAllocatedUnfairLock(initialState: State(decks: Array(repeating: DeckProgress(), count: deckNames.count)))
    }

    public func snapshot() -> ProgressSnapshot {
        let copy = state.withLock { $0 }
        return ProgressSnapshot(mode: mode, deckNames: deckNames, decks: copy.decks, elapsed: Date().timeIntervalSince(startedAt), gamesDone: copy.gamesDone, completedUnits: copy.completedUnits, currentDuel: copy.currentDuel, currentDuelGames: copy.currentDuelGames)
    }

    public func beginDuel(a: Int, b: Int) {
        state.withLock {
            $0.currentDuel = [a, b]
            $0.currentDuelGames = 0
        }
    }

    public func finishDuel(a: Int, b: Int, scoreA: Double) {
        state.withLock {
            $0.completedUnits += 1
            $0.decks[a].matchesPlayed += 1
            $0.decks[b].matchesPlayed += 1
            if scoreA > 0.5 { $0.decks[a].matchesWon += 1 }
            if scoreA < 0.5 { $0.decks[b].matchesWon += 1 }
            if scoreA == 0.5 {
                $0.decks[a].matchesDrawn += 1
                $0.decks[b].matchesDrawn += 1
            }
            $0.currentDuel = nil
        }
    }

    func publishDuel(a: Int, b: Int, batch: GameBatch) {
        guard batch.games > 0 else { return }
        state.withLock {
            $0.gamesDone += batch.games
            $0.currentDuelGames += batch.games
            if case .duel = mode { $0.completedUnits += batch.games }
            $0.decks[a].gamesPlayed += batch.games
            $0.decks[b].gamesPlayed += batch.games
            $0.decks[a].gamesWon += batch.winsA
            $0.decks[b].gamesWon += batch.winsB
        }
    }

    public func recordMatch(a: Int, b: Int, winner: Int, games: GameBatch) {
        state.withLock {
            $0.gamesDone += games.games
            $0.decks[a].gamesPlayed += games.games
            $0.decks[b].gamesPlayed += games.games
            $0.decks[a].gamesWon += games.winsA
            $0.decks[b].gamesWon += games.winsB
            $0.decks[a].matchesPlayed += 1
            $0.decks[b].matchesPlayed += 1
            $0.decks[winner].matchesWon += 1
        }
    }

    public func finishTournament(champion: Int) {
        state.withLock {
            $0.completedUnits += 1
            $0.decks[champion].titles += 1
        }
    }
}
