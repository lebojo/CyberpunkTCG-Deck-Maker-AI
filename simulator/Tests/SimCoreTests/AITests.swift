import XCTest
@testable import SimCore

final class QuickOddsTests: XCTestCase {
    func testNoQuickMeansNoThreat() {
        XCTAssertEqual(QuickOdds.atLeastOne(poolSize: 20, quickCount: 0, handSize: 5), 0)
    }

    func testAllQuickMeansCertainThreat() {
        XCTAssertEqual(QuickOdds.atLeastOne(poolSize: 6, quickCount: 6, handSize: 1), 1)
    }

    func testHypergeometricValue() {
        XCTAssertEqual(QuickOdds.atLeastOne(poolSize: 4, quickCount: 1, handSize: 2), 0.5, accuracy: 1e-9)
        XCTAssertEqual(QuickOdds.atLeastOne(poolSize: 10, quickCount: 3, handSize: 2), 1 - (7.0 / 10) * (6.0 / 9), accuracy: 1e-9)
    }

    func testHandBiggerThanNonQuickPoolIsCertain() {
        XCTAssertEqual(QuickOdds.atLeastOne(poolSize: 5, quickCount: 3, handSize: 3), 1)
    }
}

final class QuickThreatTests: XCTestCase {
    func threatGame(rivalMana: Int) -> Game {
        var game = Fixtures.game(decks: [[], ["floor-it", "floor-it", "corpo-security", "corpo-security"]])
        game.give(["corpo-security", "corpo-security"], to: 1)
        game.players[1].eddiesReady = rivalMana
        return game
    }

    func testThreatNeedsOpenMana() {
        XCTAssertEqual(threatGame(rivalMana: 0).quickThreat(of: 1), 0)
    }

    func testThreatUsesOnlyPublicInformation() {
        let game = threatGame(rivalMana: 1)
        XCTAssertEqual(game.quickThreat(of: 1), QuickOdds.atLeastOne(poolSize: 6, quickCount: 2, handSize: 2), accuracy: 1e-9)
        var swapped = game
        swapped.players[1].hand = [Fixtures.id("floor-it"), Fixtures.id("corpo-security")]
        swapped.players[1].deck = [Fixtures.id("floor-it"), Fixtures.id("corpo-security"), Fixtures.id("corpo-security"), Fixtures.id("corpo-security")]
        XCTAssertEqual(swapped.quickThreat(of: 1), game.quickThreat(of: 1), accuracy: 1e-9)
    }

    func testRevealedQuickIsCertain() {
        var game = threatGame(rivalMana: 1)
        game.addToHand(1, Fixtures.id("floor-it"))
        XCTAssertEqual(game.quickThreat(of: 1), 1)
    }

    func testDeterrenceOnlyForMarginalFights() {
        var game = threatGame(rivalMana: 1)
        let attacker = game.place("swordwise-huscle", for: 0)
        let close = game.place("la-llorona-ghost-of-the-past", for: 1)
        let weak = game.place("secondhand-bombus", for: 1)
        let unit = game.unit(0, attacker)!
        XCTAssertGreaterThan(game.quickDeterrence(attacker: 0, unit: unit, target: .unit(close), threat: 0.5), 0)
        XCTAssertEqual(game.quickDeterrence(attacker: 0, unit: unit, target: .unit(weak), threat: 0), 0)
    }
}

final class DefenseValueTests: XCTestCase {
    func testBlockerStopsAttackerItMatches() {
        let value = DefenseValue.of(blockers: [5], attackers: [IncomingAttacker(power: 4, weight: 1, unblockable: false)], attackWorth: { Double(Fixtures.game().stealCount(forPower: $0)) * 10 })
        XCTAssertEqual(value, 10)
    }

    func testWeakBlockerDoesNotCount() {
        XCTAssertEqual(DefenseValue.of(blockers: [3], attackers: [IncomingAttacker(power: 4, weight: 1, unblockable: false)], attackWorth: { Double(Fixtures.game().stealCount(forPower: $0)) * 10 }), 0)
    }

    func testUnblockableIgnored() {
        XCTAssertEqual(DefenseValue.of(blockers: [9], attackers: [IncomingAttacker(power: 4, weight: 1, unblockable: true)], attackWorth: { Double(Fixtures.game().stealCount(forPower: $0)) * 10 }), 0)
    }

    func testEachBlockerUsedOnceAgainstBiggestThreat() {
        let attackers = [IncomingAttacker(power: 3, weight: 1, unblockable: false), IncomingAttacker(power: 12, weight: 0.5, unblockable: false)]
        XCTAssertEqual(DefenseValue.of(blockers: [14], attackers: attackers, attackWorth: { Double(Fixtures.game().stealCount(forPower: $0)) * 10 }), 0.5 * 2 * 10)
    }

    func testReadyBlockerHasGuardValueAgainstNextTurnAttackers() {
        var game = Fixtures.game()
        let blocker = game.place("la-llorona-ghost-of-the-past", for: 0)
        game.place("swordwise-huscle", for: 1, ready: false)
        game.setGigs([(4, 1), (6, 2)], for: 0)
        XCTAssertGreaterThan(game.guardCost(0, game.unit(0, blocker)!), 0)
        game.spendUnit(0, uid: blocker)
        XCTAssertEqual(game.defenseValue(0), 0)
    }

    func testAdrenalineUnitInRivalPoolCountsAsIncoming() {
        var game = Fixtures.game(decks: [[], ["modded-kusanagi", "corpo-security"]])
        game.give(["corpo-security"], to: 1)
        game.players[1].eddiesReady = 6
        let incoming = game.incomingAttackers(against: 0)
        XCTAssertEqual(incoming.count, 1)
        XCTAssertEqual(incoming[0].power, 8)
        XCTAssertGreaterThan(incoming[0].weight, 0)
    }
}

final class HoldingTests: XCTestCase {
    func searchPolicy(bluff: Bool) -> Policy {
        Policy(search: true, config: SearchConfig(bluff: bluff))
    }

    func testBluffOfferedWhenDeckHasQuickAndManaIsOpen() {
        var game = Fixtures.game(decks: [["floor-it", "corpo-security"], []])
        game.policies = SidePair(searchPolicy(bluff: true), searchPolicy(bluff: true))
        game.players[0].eddiesReady = 2
        XCTAssertTrue(game.candidateActions(0).contains(.bluff(reserve: 1)))
        game.policies[0] = searchPolicy(bluff: false)
        XCTAssertFalse(game.candidateActions(0).contains(.bluff(reserve: 1)))
    }

    func testLegacyPolicyHasNoHoldingActions() {
        var game = Fixtures.game(decks: [["floor-it", "corpo-security"], []])
        game.policies = SidePair(searchPolicy(bluff: true).legacy, .greedy)
        game.players[0].eddiesReady = 2
        game.place("la-llorona-ghost-of-the-past", for: 0)
        XCTAssertTrue(game.holdingActions(0).isEmpty)
    }

    func testBluffKeepsManaAndUnitsReady() {
        var game = Fixtures.game(decks: [["floor-it"], []])
        game.policies = SidePair(searchPolicy(bluff: true), .greedy)
        game.players[0].eddiesReady = 3
        game.give(["swordwise-huscle"], to: 0)
        let unit = game.place("la-llorona-ghost-of-the-past", for: 0)
        game.setGigs([(4, 1)], for: 1)
        XCTAssertTrue(game.apply(.bluff(reserve: 1), 0))
        XCTAssertGreaterThanOrEqual(game.availableMana(0), 1)
        XCTAssertFalse(game.unit(0, unit)!.spent)
    }
}

final class ReviewFixTests: XCTestCase {
    func testGuardHomeStillCallsLegend() {
        var game = Fixtures.game(legends: [["royce-psycho-on-the-edge"], []])
        game.policies = SidePair(Policy(search: true), Policy(search: true))
        game.players[0].eddiesReady = 1
        game.place("la-llorona-ghost-of-the-past", for: 0)
        XCTAssertTrue(game.apply(.guardHome, 0))
        XCTAssertTrue(game.players[0].flags.called)
    }

    func testBluffKeepsItsReserveBeforeCallingLegend() {
        var game = Fixtures.game(legends: [["royce-psycho-on-the-edge"], []], decks: [["floor-it"], []])
        game.policies = SidePair(Policy(search: true, config: SearchConfig(bluff: true)), .greedy)
        game.players[0].eddiesReady = 0
        XCTAssertTrue(game.apply(.bluff(reserve: 1), 0))
        XCTAssertFalse(game.players[0].flags.called)
        XCTAssertEqual(game.availableMana(0), 1)
    }

    func testSimulatedRivalUsesItsOwnSeatPolicy() {
        var game = Fixtures.game()
        game.policies = SidePair(Policy(search: true, config: SearchConfig(bluff: true)), Policy(search: true).legacy)
        let simulated = game.simulatedPolicies(for: 0)
        XCTAssertTrue(simulated[1].config.legacy)
        XCTAssertFalse(simulated[1].config.bluff)
        XCTAssertTrue(simulated[1].config.isSimulatedOpponent)
        XCTAssertTrue(simulated[0].config.bluff)
    }

    func testGreedyRivalIsSimulatedGreedy() {
        var game = Fixtures.game()
        game.policies = SidePair(Policy(search: true), Policy(search: false))
        XCTAssertFalse(game.simulatedPolicies(for: 0)[1].search)
    }

    func testOnlySimulatedOpponentIsFlagged() {
        XCTAssertFalse(SearchConfig().isSimulatedOpponent)
        XCTAssertTrue(SearchConfig().simulatedOpponent(playing: SearchConfig()).isSimulatedOpponent)
    }

    func testRushManaCountsSpentLegendsThatReadyNextTurn() {
        var game = Fixtures.game(legends: [[], ["royce-psycho-on-the-edge", "dum-dum-maelstrom-triggerman"]], decks: [[], ["modded-kusanagi", "corpo-security"]])
        game.players[1].eddiesSpent = 4
        for slot in game.players[1].legends.indices { game.players[1].legends[slot].spent = true }
        XCTAssertEqual(game.rushThreats(from: 1).first?.power, 8)
    }
}

final class DefenseScenarioTests: XCTestCase {
    func defenseGame(rivalAttackers: Int) -> Game {
        var game = Fixtures.game(turn: 6)
        game.policies = SidePair(Policy(search: true), Policy(search: true))
        game.place("la-llorona-ghost-of-the-past", for: 0)
        game.setGigs([(4, 2), (6, 3), (8, 4)], for: 0)
        game.setGigs([(4, 1), (6, 2), (8, 3), (10, 4), (12, 5), (20, 6)], for: 1)
        for _ in 0..<rivalAttackers { game.place("swordwise-huscle", for: 1, ready: false) }
        game.players[0].fixer = []
        game.players[1].fixer = []
        return game
    }

    func testKeepsBlockerHomeWhenRivalThreatensGigs() {
        var game = defenseGame(rivalAttackers: 1)
        game.policies[0].search = false
        let blocker = game.players[0].field[0].uid
        let rivalBlocker = game.place("corpo-security", for: 1, ready: true)
        game.spendUnit(1, uid: rivalBlocker)
        XCTAssertNil(game.bestAttack(0).flatMap { $0.uid == blocker ? $0 : nil })
    }

    func testAttacksWhenNothingThreatens() {
        var game = defenseGame(rivalAttackers: 0)
        game.policies[0].search = false
        XCTAssertNotNil(game.bestAttack(0))
    }

    func guardGame() -> Game {
        var game = Fixtures.game(turn: 6)
        game.policies = SidePair(Policy(search: true, config: SearchConfig(samples: 2, depth: 2, shortlist: 3)), Policy(search: true))
        game.place("meredith-stout-stone-cold-corpo", for: 0)
        game.setGigs([(4, 2), (6, 3), (8, 4), (10, 5), (12, 6), (20, 7)], for: 0)
        game.place("swordwise-huscle", for: 1, ready: false)
        let prey = game.place("corpo-security", for: 1)
        game.spendUnit(1, uid: prey)
        game.players[0].fixer = []
        game.players[1].fixer = []
        return game
    }

    func testSearchKeepsBlockerHomeInsteadOfAFreeKill() {
        var game = guardGame()
        let blocker = game.players[0].field[0].uid
        game.searchMainPhase(0)
        XCTAssertEqual(game.unit(0, blocker)?.spent, false)
    }

    func testGreedyPolicyWeighsTheGuardButLegacyDoesNot() {
        var game = guardGame()
        game.policies[0] = Policy(search: false)
        XCTAssertNil(game.bestAttack(0))
        game.policies[0] = Policy(search: false).legacy
        XCTAssertNotNil(game.bestAttack(0))
    }

    func testSearchAttacksWhenNothingThreatens() {
        var game = defenseGame(rivalAttackers: 0)
        game.policies[0] = Policy(search: true, config: SearchConfig(samples: 2, depth: 2, shortlist: 3))
        let blocker = game.players[0].field[0].uid
        let before = game.players[0].gigs.count
        game.searchMainPhase(0)
        XCTAssertEqual(game.unit(0, blocker)?.spent, true)
        XCTAssertGreaterThan(game.players[0].gigs.count, before)
    }

    func testLegacyAttacksEvenWhenThreatened() {
        var game = defenseGame(rivalAttackers: 1)
        game.policies[0] = Policy(search: false).legacy
        XCTAssertNotNil(game.bestAttack(0))
    }
}

final class SearchDeterminismTests: XCTestCase {
    func testSearchPolicyWithSimulatedOpponentIsDeterministic() {
        let deck = DeckList(name: "A", legends: ["dum-dum-maelstrom-triggerman", "river-ward-detective-on-the-hunt", "royce-psycho-on-the-edge"].map { Fixtures.id($0) },
                            main: Array(repeating: Fixtures.id("swordwise-huscle"), count: 14) + Array(repeating: Fixtures.id("la-llorona-ghost-of-the-past"), count: 14) + Array(repeating: Fixtures.id("floor-it"), count: 12))
        let policy = Policy(search: true, config: SearchConfig(samples: 1, depth: 1, shortlist: 1, maxSteps: 3))
        let first = Simulator.playOne(catalog: Fixtures.catalog, decks: [deck, deck], index: 1, seed: 5, policies: [policy, policy]).summary
        let second = Simulator.playOne(catalog: Fixtures.catalog.isolatedCopy(), decks: [deck, deck], index: 1, seed: 5, policies: [policy, policy]).summary
        XCTAssertEqual(first.winner, second.winner)
        XCTAssertEqual(first.turns, second.turns)
    }
}
