import XCTest
@testable import SimCore

final class ReviewFixesTests: XCTestCase {
    func id(_ key: String) -> Int { Fixtures.id(key) }

    func deck(legends: [String], mainCount: Int = 40) -> DeckList {
        DeckList(name: "test", legends: legends.map(id), main: Array(repeating: id("psycho-squad"), count: mainCount))
    }

    func testGameSetupDoesNotCrashWithTooFewLegends() {
        for legends in [[], ["royce-psycho-on-the-edge"]] {
            let decks = [deck(legends: legends), deck(legends: legends)]
            let game = Game(catalog: Fixtures.catalog, decks: decks, seed: 3, firstPlayer: 0, tracing: false)
            XCTAssertEqual(game.players[0].legends.count, legends.count)
        }
    }

    func testInvalidDecksAreRejectedWithAFrenchMessage() {
        let valid = deck(legends: ["royce-psycho-on-the-edge", "goro-takemura-hands-unclean", "jackie-welles-mama-s-favorite"])
        XCTAssertNil(DeckList.validationError(for: [valid, valid]))
        let text = "Legends\n2 Royce - Psycho on the Edge\nMain\n10 Psycho Squad\n1 Carte Imaginaire\n"
        let broken = DeckList.parse(text: text, fallbackName: "cassé", catalog: Fixtures.catalog)
        let message = DeckList.validationError(for: [valid, broken])
        XCTAssertNotNil(message)
        XCTAssertTrue(message?.contains("cassé") ?? false)
        XCTAssertTrue(message?.contains("Légendes") ?? false)
    }

    func testUnitDiscountOnlyAppliesToTheNextUnit() {
        var game = Fixtures.game()
        let squad = id("psycho-squad")
        game.addPendingDiscount(0, source: id("alt-cunningham-soulkiller-architect"), kind: .unit, amount: 2, minimum: 1)
        XCTAssertEqual(game.effectiveCost(0, squad), 2)
        game.players[0].eddiesReady = 10
        game.give(["psycho-squad", "psycho-squad"], to: 0)
        XCTAssertTrue(game.playFromHand(0, handIndex: 0))
        XCTAssertEqual(game.effectiveCost(0, squad), 4)
    }

    func testProgramDiscountIsConsumedByAQuick() {
        var game = Fixtures.game()
        let floorIt = id("floor-it")
        let safety = id("safety-override")
        game.addPendingDiscount(0, source: id("alt-cunningham-soulkiller-architect"), kind: .program, amount: 1, minimum: 0)
        game.players[0].eddiesReady = 10
        game.give(["floor-it"], to: 0)
        XCTAssertEqual(game.effectiveCost(0, floorIt), 0)
        XCTAssertTrue(game.playQuickFromHand(0, cardId: floorIt))
        XCTAssertEqual(game.effectiveCost(0, safety), 2)
    }

    func testGoSoloDiscountOnlyAppliesOnce() {
        var game = Fixtures.game(legends: [["royce-psycho-on-the-edge", "goro-takemura-hands-unclean"], []])
        game.addPendingDiscount(0, source: id("alt-cunningham-soulkiller-architect"), kind: .legend, amount: 2, minimum: 1)
        game.players[0].eddiesReady = 10
        XCTAssertEqual(game.goSoloCost(0, slot: 1), 3)
        game.goSolo(0, slot: 0)
        XCTAssertEqual(game.players[0].legends.count, 1)
        XCTAssertEqual(game.goSoloCost(0, slot: 0), 5)
    }

    func testPlayedRevealedCardIsForgottenWhenAHiddenCopyIsDrawn() {
        var game = Fixtures.game()
        let squad = id("psycho-squad")
        game.players[0].eddiesReady = 10
        game.addToHand(0, squad, revealed: true)
        XCTAssertEqual(game.knownHandCards(of: 0), [squad])
        XCTAssertTrue(game.playFromHand(0, handIndex: 0))
        game.addToHand(0, squad, revealed: false)
        XCTAssertEqual(game.knownHandCards(of: 0), [])
    }

    func testDiscardedRevealedCardIsForgotten() {
        var game = Fixtures.game()
        let squad = id("psycho-squad")
        game.addToHand(0, squad, revealed: true)
        game.discardWorst(0)
        game.addToHand(0, squad, revealed: false)
        XCTAssertEqual(game.knownHandCards(of: 0), [])
    }

    func testExpiredLingeringPowerDoesNotStack() {
        var game = Fixtures.game(turn: 3)
        let uid = game.place("psycho-squad", for: 0)
        let source = id("psycho-squad")
        game.withContext(source, owner: 0, at: .resolving) { $0.addPower(0, uid: uid, 2, .untilYourNextTurn) }
        XCTAssertEqual(game.power(0, game.unit(0, uid)!, attacking: false), 8)
        game.turn = 5
        game.withContext(source, owner: 0, at: .resolving) { $0.addPower(0, uid: uid, 1, .untilYourNextTurn) }
        XCTAssertEqual(game.power(0, game.unit(0, uid)!, attacking: false), 7)
    }

    func testRivalUnitMarkedToBeDefeatedAtEndOfTurnIsDefeated() {
        var game = Fixtures.game()
        let uid = game.place("psycho-squad", for: 1)
        game.withContext(id("psycho-squad"), owner: 0, at: .resolving) { $0.defeatAtEndOfTurn(1, uid: uid) }
        game.endTurn(0)
        XCTAssertNil(game.unit(1, uid))
        XCTAssertEqual(game.players[1].trash, [id("psycho-squad")])
    }

    func testTurnLimitIsReportedAsAGameEnding() {
        var game = Fixtures.game(turn: Game.turnLimit)
        game.playTurn()
        guard case .draw(let reason) = game.outcome else { return XCTFail("la partie devrait être nulle") }
        XCTAssertEqual(reason, .turnLimit)
        var stats = DuelStats()
        stats.add(GameSummary(winner: nil, reason: reason, turns: 61, firstPlayer: 0, mulligans: [false, false]))
        let a = deck(legends: [])
        XCTAssertTrue(Report.duel(a: a, b: a, stats: stats).contains("limite de tours 100.0%"))
        XCTAssertTrue(Report.duelMarkdown(a: a, b: a, stats: stats).contains("limite de tours 100.0%"))
    }

    func testSignalMessageIsPreparedBeforeAnySignal() {
        XCTAssertEqual(String(cString: LiveDisplay.restoreCursorBytes), "\u{1B}[?25h\n")
        XCTAssertEqual(LiveDisplay.restoreCursorLength, 7)
    }

    func testPadreSpendsADangerousRivalUnit() {
        var game = Fixtures.game(legends: [["padre-man-of-the-cross"], []])
        let threat = game.place("saul-bright-stormrider", for: 1)
        game.callLegend(0, 0, free: true)
        XCTAssertTrue(game.unit(1, threat)!.spent)
        XCTAssertTrue(game.players[0].hand.isEmpty)
    }

    func testPadreDrawsWhenNoRivalUnitStands() {
        var game = Fixtures.game(legends: [["padre-man-of-the-cross"], []])
        game.callLegend(0, 0, free: true)
        XCTAssertEqual(game.players[0].hand.count, 1)
    }

    func testWakakoWeakensTheUnitWhoseFightItSwings() {
        var game = Fixtures.game(legends: [["wakako-okada-peace-and-harmony"], []])
        game.place("psycho-squad", for: 0)
        let target = game.place("psycho-squad", for: 1)
        game.spendUnit(1, uid: target)
        game.callLegend(0, 0, free: true)
        XCTAssertEqual(game.power(1, game.unit(1, target)!, attacking: false), 4)
        XCTAssertTrue(game.players[0].hand.isEmpty)
    }

    func testDexterPumpsTheAttackerWhoseFightItSwings() {
        var game = Fixtures.game(legends: [["dexter-deshawn-off-the-grid"], []])
        let attacker = game.place("psycho-squad", for: 0)
        let target = game.place("psycho-squad", for: 1)
        game.spendUnit(1, uid: target)
        game.callLegend(0, 0, free: true)
        XCTAssertEqual(game.power(0, game.unit(0, attacker)!, attacking: true), 8)
        XCTAssertTrue(game.players[0].hand.isEmpty)
    }

    func testDexterDrawsWithoutAnAttacker() {
        var game = Fixtures.game(legends: [["dexter-deshawn-off-the-grid"], []])
        game.callLegend(0, 0, free: true)
        XCTAssertEqual(game.players[0].hand.count, 1)
    }

    func testMuamarProtectsAnAttackerFacingAStrongerTarget() {
        var game = Fixtures.game(legends: [["muamar-reyes-el-capit-n"], []])
        game.place("psycho-squad", for: 0)
        let saul = game.place("saul-bright-stormrider", for: 1)
        game.spendUnit(1, uid: saul)
        game.callLegend(0, 0, free: true)
        XCTAssertTrue(game.players[0].hand.isEmpty)
        XCTAssertFalse(game.players[0].flags.delayedTriggers.isEmpty)
    }

    func testFoolOnTheHillRivalTrashesStrongCards() {
        var game = Fixtures.game(decks: [Array(repeating: "corpo-security", count: 8) + ["saul-bright-stormrider", "saul-bright-stormrider"], []])
        game.playProgram(0, id("fool-on-the-hill"), bottomAfter: false)
        XCTAssertFalse(game.players[0].hand.contains(id("saul-bright-stormrider")))
        XCTAssertEqual(game.players[0].trash.filter { $0 == self.id("saul-bright-stormrider") }.count, 2)
    }

    func testRejectedModeTrialsDoNotWriteToTheTrace() {
        let custom = EffectAPITests().catalog(with: ["rockn-rockerboy": { ModeTraceTestCard(data: $0) }])
        var traced = Fixtures.game(catalog: custom)
        traced.tracing = true
        let tracedLog = TraceLog()
        traced.log = tracedLog
        traced.playProgram(0, Fixtures.id("rockn-rockerboy", in: custom), bottomAfter: false)
        XCTAssertEqual(tracedLog.lines.filter { $0.hasPrefix("mode") }, ["mode 1"])
    }
}

struct ModeTraceTestCard: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        _ = context.chooseMode(2) { mode, branch in
            branch.note("mode \(mode)")
            if mode == 1 { branch.draw(2) }
        }
    }
}
