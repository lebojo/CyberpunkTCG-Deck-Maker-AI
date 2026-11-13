import XCTest
@testable import SimCore

final class RulesTests: XCTestCase {
    func testStealsOneGigPerTenPower() {
        var game = Fixtures.game()
        XCTAssertEqual(game.stealCount(forPower: 0), 0)
        XCTAssertEqual(game.stealCount(forPower: 9), 1)
        XCTAssertEqual(game.stealCount(forPower: 10), 2)
        XCTAssertEqual(game.stealCount(forPower: 21), 3)
        let attacker = game.place("saul-bright-stormrider", for: 0)
        game.setGigs([(4, 1), (6, 2), (8, 3)], for: 1)
        game.performAttack(0, attackerUid: attacker, target: .gigs)
        XCTAssertEqual(game.players[0].gigs.count, 2)
        XCTAssertEqual(game.players[1].gigs.count, 1)
    }

    func testZeroPowerUnitStealsNothing() {
        var game = Fixtures.game()
        let ripper = game.place("secondhand-bombus", for: 0)
        game.setGigs([(4, 1)], for: 1)
        game.performAttack(0, attackerUid: ripper, target: .gigs)
        XCTAssertEqual(game.players[1].gigs.count, 1)
    }

    func testBlockerRedirectsAttackAndFightDefeatsTheLoser() {
        var game = Fixtures.game()
        let attacker = game.place("swordwise-huscle", for: 0)
        let blocker = game.place("corpo-security", for: 1)
        game.setGigs([(4, 2), (6, 3), (8, 4), (10, 5), (12, 6)], for: 1)
        game.performAttack(0, attackerUid: attacker, target: .gigs)
        XCTAssertNil(game.unit(1, blocker))
        XCTAssertNotNil(game.unit(0, attacker))
        XCTAssertEqual(game.players[1].gigs.count, 5)
    }

    func testSpentBlockerCannotBlock() {
        var game = Fixtures.game()
        let attacker = game.place("swordwise-huscle", for: 0)
        let blocker = game.place("corpo-security", for: 1)
        game.spendUnit(1, uid: blocker)
        game.setGigs([(4, 2)], for: 1)
        game.performAttack(0, attackerUid: attacker, target: .gigs)
        XCTAssertEqual(game.players[0].gigs.count, 1)
    }

    func testNewUnitLagsUnlessItHasAdrenaline() {
        var game = Fixtures.game()
        game.setGigs([(4, 2)], for: 1)
        let lagging = game.place("swordwise-huscle", for: 0, ready: false)
        let fast = game.place("modded-kusanagi", for: 0, ready: false)
        XCTAssertFalse(game.canAttackAtAll(0, game.unit(0, lagging)!))
        XCTAssertTrue(game.canAttackAtAll(0, game.unit(0, fast)!))
    }

    func testPlayerWithSevenGigsWinsAtStartOfTurn() {
        var game = Fixtures.game()
        game.setGigs(Array(repeating: (6, 3), count: 7), for: 0)
        game.playTurn()
        guard case .win(let player, let reason) = game.outcome else { return XCTFail("partie non terminée") }
        XCTAssertEqual(player, 0)
        XCTAssertEqual(reason, .gigsAtStart)
    }

    func testSellingHappensOncePerTurn() {
        var game = Fixtures.game()
        game.give(["floor-it", "floor-it", "trust-no-one", "detonate"], to: 0)
        game.sellIfUseful(0)
        game.sellIfUseful(0)
        XCTAssertEqual(game.players[0].eddiesReady, 1)
        XCTAssertEqual(game.players[0].hand.count, 3)
    }

    func testCallingALegendCostsOneAndOnlyOncePerTurn() {
        var game = Fixtures.game(legends: [["royce-psycho-on-the-edge", "saburo-arasaka-stubborn-patriarch", "v-streetkid"], []])
        game.players[0].eddiesReady = 2
        game.callLegendIfUseful(0)
        game.callLegendIfUseful(0)
        XCTAssertEqual(game.players[0].legends.filter(\.faceUp).count, 1)
        XCTAssertEqual(game.players[0].eddiesReady, 1)
        XCTAssertTrue(game.players[0].flags.called)
    }

    func testMulliganOnlyForClearlyBadHands() {
        let heavy = Array(repeating: "minotaur", count: 6)
        let light = ["swordwise-huscle", "corpo-security", "mantis-blades", "floor-it", "trust-no-one", "satori-sword-of-saburo"]
        let pool = Array(repeating: "swordwise-huscle", count: 20) + Array(repeating: "floor-it", count: 20)
        var bad = Fixtures.game(decks: [pool, []])
        bad.give(heavy, to: 0)
        var good = Fixtures.game(decks: [pool, []])
        good.give(light, to: 0)
        XCTAssertTrue(bad.shouldMulligan(0))
        XCTAssertFalse(good.shouldMulligan(0))
    }

    func testDrawingFromEmptyDeckLoses() {
        var game = Fixtures.game()
        game.players[0].deck = []
        game.draw(0, 1)
        guard case .win(let player, let reason) = game.outcome else { return XCTFail("partie non terminée") }
        XCTAssertEqual(player, 1)
        XCTAssertEqual(reason, .deckOut)
    }

    func testDeterministicGreedyGames() throws {
        let catalog = Fixtures.catalog
        let deck = DeckList(name: "A", legends: ["dum-dum-maelstrom-triggerman", "river-ward-detective-on-the-hunt", "royce-psycho-on-the-edge"].map { Fixtures.id($0) },
                            main: Array(repeating: Fixtures.id("swordwise-huscle"), count: 20) + Array(repeating: Fixtures.id("mantis-blades"), count: 20))
        let first = Simulator.playOne(catalog: catalog, decks: [deck, deck], index: 3, seed: 9, search: [false, false]).summary
        let second = Simulator.playOne(catalog: catalog.isolatedCopy(), decks: [deck, deck], index: 3, seed: 9, search: [false, false]).summary
        XCTAssertEqual(first.winner, second.winner)
        XCTAssertEqual(first.turns, second.turns)
    }
}
