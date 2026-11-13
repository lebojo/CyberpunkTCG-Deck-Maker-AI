import XCTest
@testable import SimCore

final class LiveDashboardTests: XCTestCase {
    func snapshot(mode: ProgressMode = .tournament(count: 100), done: Int, names: [String] = ["Alpha", "Beta", "Gamma"], elapsed: Double = 60) -> ProgressSnapshot {
        var decks = names.map { _ in DeckProgress() }
        for (index, titles) in [1, 5, 3].enumerated() where index < decks.count { decks[index].titles = titles }
        for index in decks.indices {
            decks[index].matchesPlayed = 10
            decks[index].matchesWon = index + 3
            decks[index].gamesPlayed = 20
            decks[index].gamesWon = index + 8
        }
        return ProgressSnapshot(mode: mode, deckNames: names, decks: decks, elapsed: elapsed, gamesDone: 600, completedUnits: done)
    }

    func testProgressBarAtZeroHalfAndFull() {
        XCTAssertEqual(LiveDashboard.progressBar(fraction: 0, width: 12), "[" + String(repeating: "░", count: 10) + "]")
        XCTAssertEqual(LiveDashboard.progressBar(fraction: 0.5, width: 12), "[" + String(repeating: "█", count: 5) + String(repeating: "░", count: 5) + "]")
        XCTAssertEqual(LiveDashboard.progressBar(fraction: 1, width: 12), "[" + String(repeating: "█", count: 10) + "]")
    }

    func testPercentLinesAtZeroHalfAndFull() {
        for (done, text) in [(0, "  0.0%"), (50, " 50.0%"), (100, "100.0%")] {
            let lines = LiveDashboard.lines(snapshot(done: done), width: 100)
            XCTAssertTrue(lines[1].contains(text), lines[1])
        }
    }

    func testTournamentTableSortedByTitles() {
        let lines = LiveDashboard.tableLines(snapshot(done: 50), width: 100)
        XCTAssertTrue(lines[1].contains("Beta"))
        XCTAssertTrue(lines[2].contains("Gamma"))
        XCTAssertTrue(lines[3].contains("Alpha"))
        XCTAssertTrue(lines[0].contains("Tournois"))
    }

    func testNonTournamentSortedByGameWinRate() {
        let lines = LiveDashboard.tableLines(snapshot(mode: .matrix(duels: 3, gamesPerDuel: 10), done: 1), width: 100)
        XCTAssertTrue(lines[1].contains("Gamma"))
        XCTAssertTrue(lines[3].contains("Alpha"))
    }

    func testDurationFormatting() {
        XCTAssertEqual(LiveDashboard.duration(0), "0s")
        XCTAssertEqual(LiveDashboard.duration(45), "45s")
        XCTAssertEqual(LiveDashboard.duration(185), "3m05s")
        XCTAssertEqual(LiveDashboard.duration(3720), "1h02m")
    }

    func testEtaFromFraction() {
        XCTAssertEqual(LiveDashboard.etaText(snapshot(done: 0)), "--")
        XCTAssertEqual(LiveDashboard.etaText(snapshot(done: 25, elapsed: 60)), "~3m00s")
    }

    func testTruncateLongNames() {
        XCTAssertEqual(LiveDashboard.truncate("abcdefghij", 5), "abcd…")
        XCTAssertEqual(LiveDashboard.truncate("abc", 5), "abc")
        let long = String(repeating: "x", count: 80)
        let lines = LiveDashboard.tableLines(snapshot(done: 10, names: [long, "B", "C"]), width: 100)
        XCTAssertTrue(lines[1].contains("…") || lines[2].contains("…") || lines[3].contains("…"))
        XCTAssertTrue(lines.allSatisfy { $0.count <= 99 })
    }

    func testNarrowWidthKeepsLinesShortAndDropsColumns() {
        let lines = LiveDashboard.lines(snapshot(done: 50, names: ["Un deck au nom vraiment tres long", "B", "C"]), width: 40)
        XCTAssertTrue(lines.allSatisfy { $0.count <= 39 }, lines.joined(separator: "\n"))
        XCTAssertFalse(lines.joined().contains("Gagnés"))
    }

    func testStatusLineHasNoEscapeAndNamesBestDeck() {
        let line = LiveDashboard.statusLine(snapshot(done: 25))
        XCTAssertFalse(line.contains("\u{1B}"))
        XCTAssertTrue(line.contains("25.0%"))
        XCTAssertTrue(line.contains("Beta"))
    }

    func testDuelDetailShowsWinRateAndMargin() {
        var snap = snapshot(mode: .duel(games: 100), done: 40, names: ["A", "B"])
        snap.decks[0].gamesWon = 30
        snap.decks[1].gamesWon = 10
        snap.gamesDone = 40
        XCTAssertTrue(LiveDashboard.lines(snap, width: 100)[3].contains("75.0% ±"))
    }
}

final class ProgressTrackerTests: XCTestCase {
    func testConcurrentUpdatesStayConsistent() async {
        let tracker = ProgressTracker(mode: .tournament(count: 8000), deckNames: ["A", "B", "C"])
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    for _ in 0..<1000 {
                        tracker.recordMatch(a: 0, b: 1, winner: 0, games: GameBatch(games: 3, winsA: 2, winsB: 1))
                        tracker.finishTournament(champion: 2)
                    }
                }
            }
        }
        let snap = tracker.snapshot()
        XCTAssertEqual(snap.completedUnits, 8000)
        XCTAssertEqual(snap.gamesDone, 24000)
        XCTAssertEqual(snap.decks[0].matchesWon, 8000)
        XCTAssertEqual(snap.decks[1].gamesWon, 8000)
        XCTAssertEqual(snap.decks[2].titles, 8000)
        XCTAssertEqual(snap.fraction, 1)
    }

    func testDuelProgressCountsGames() {
        let tracker = ProgressTracker(mode: .duel(games: 10), deckNames: ["A", "B"])
        let progress = DuelProgress(tracker: tracker, a: 0, b: 1)
        var batch = GameBatch()
        for winner in [0, 1, nil, 0] as [Int?] { batch.add(winner: winner) }
        progress.publish(batch)
        let snap = tracker.snapshot()
        XCTAssertEqual(snap.completedUnits, 4)
        XCTAssertEqual(snap.decks[0].gamesWon, 2)
        XCTAssertEqual(snap.decks[1].gamesWon, 1)
        XCTAssertEqual(snap.decks[0].gamesPlayed, 4)
    }

    func testMatrixDuelFinish() {
        let tracker = ProgressTracker(mode: .matrix(duels: 3, gamesPerDuel: 10), deckNames: ["A", "B", "C"])
        tracker.beginDuel(a: 0, b: 1)
        XCTAssertEqual(tracker.snapshot().currentDuel, [0, 1])
        tracker.finishDuel(a: 0, b: 1, scoreA: 0.6)
        let snap = tracker.snapshot()
        XCTAssertNil(snap.currentDuel)
        XCTAssertEqual(snap.completedUnits, 1)
        XCTAssertEqual(snap.decks[0].matchesWon, 1)
        XCTAssertEqual(snap.decks[1].matchesWon, 0)
    }

    func testMatrixProgressInterpolatesCurrentDuel() {
        let tracker = ProgressTracker(mode: .matrix(duels: 2, gamesPerDuel: 100), deckNames: ["A", "B", "C"])
        tracker.beginDuel(a: 0, b: 1)
        DuelProgress(tracker: tracker, a: 0, b: 1).publish(GameBatch(games: 50, winsA: 25, winsB: 25))
        let snap = tracker.snapshot()
        XCTAssertEqual(snap.fraction, 0.25, accuracy: 1e-9)
        XCTAssertNotNil(snap.etaSeconds)
    }

    func testDrawnDuelIsHalfAWinForBoth() {
        let tracker = ProgressTracker(mode: .matrix(duels: 3, gamesPerDuel: 10), deckNames: ["A", "B", "C"])
        tracker.beginDuel(a: 0, b: 1)
        tracker.finishDuel(a: 0, b: 1, scoreA: 0.5)
        let snap = tracker.snapshot()
        XCTAssertEqual(snap.decks[0].matchWinRate, 0.5)
        XCTAssertEqual(snap.decks[1].matchWinRate, 0.5)
        XCTAssertTrue(LiveDashboard.tableLines(snap, width: 100).joined().contains("0.5"))
    }
}

final class LiveDisplayTests: XCTestCase {
    func testLiveOutputGoesToStandardError() {
        XCTAssertEqual(LiveDisplay.descriptor, STDERR_FILENO)
    }

    func testEveryLineFitsTheCurrentWidth() {
        let lines = LiveDisplay.fitted(["x" + String(repeating: "y", count: 60), "court"], width: 12)
        XCTAssertTrue(lines.allSatisfy { $0.count <= 11 })
    }

    func testRedrawClimbsRowsReflowedByANarrowerTerminal() {
        let previous = LiveDisplay.Frame(lengths: [79, 10])
        XCTAssertEqual(previous.rowsOccupied(width: 80), 2)
        XCTAssertEqual(previous.rowsOccupied(width: 40), 3)
        XCTAssertTrue(LiveDisplay.frameText(["a"], after: previous, width: 40).hasPrefix("\u{1B}[3A"))
    }

    func testStopRestoresPreviousSignalHandler() {
        let custom: @convention(c) (Int32) -> Void = { _ in }
        let original = signal(SIGTERM, custom)
        let display = LiveDisplay.start(tracker: ProgressTracker(mode: .duel(games: 1), deckNames: ["A", "B"]), interactive: true)
        display.stop()
        let current = signal(SIGTERM, original)
        XCTAssertEqual(current.map { unsafeBitCast($0, to: Int.self) }, unsafeBitCast(custom, to: Int.self))
    }
}

final class TournamentSeatTests: XCTestCase {
    func testFirstDeckKeepsFirstSeatPolicy() {
        let policies = [Policy(search: true), Policy(search: true).legacy]
        XCTAssertEqual(Tournament.seatPolicy(policies, deck: 0), policies[0])
        XCTAssertEqual(Tournament.seatPolicy(policies, deck: 3), policies[1])
    }
}
