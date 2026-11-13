import XCTest
@testable import SimCore

final class CardEffectTests: XCTestCase {
    func testPlayEffectFieldOperatorDrawsOnEvenStreetCred() {
        var game = Fixtures.game()
        game.setGigs([(4, 2)], for: 0)
        game.give(["field-operator"], to: 0)
        game.players[0].eddiesReady = 3
        XCTAssertTrue(game.playFromHand(0, handIndex: 0))
        XCTAssertEqual(game.players[0].hand.count, 1)
        XCTAssertEqual(game.players[0].field.count, 1)
    }

    func testPlayEffectFieldOperatorDoesNothingOnOddStreetCred() {
        var game = Fixtures.game()
        game.setGigs([(4, 3)], for: 0)
        game.give(["field-operator"], to: 0)
        game.players[0].eddiesReady = 3
        game.playFromHand(0, handIndex: 0)
        XCTAssertTrue(game.players[0].hand.isEmpty)
    }

    func testAttackEffectHuscleDrawsWithFivePower() {
        var game = Fixtures.game()
        let huscle = game.place("swordwise-huscle", for: 0, gears: ["mantis-blades"])
        game.setGigs([(4, 1)], for: 1)
        game.performAttack(0, attackerUid: huscle, target: .gigs)
        XCTAssertEqual(game.players[0].hand.count, 1)
        XCTAssertEqual(game.players[0].gigs.count, 1)
    }

    func testDefeatedEffectScrewReturnsAnotherUnit() {
        var game = Fixtures.game()
        let screw = game.place("screw-lovelorn-fool", for: 0)
        game.players[0].trash = [Fixtures.id("minotaur"), Fixtures.id("floor-it")]
        game.defeat(0, uid: screw)
        XCTAssertEqual(game.players[0].hand, [Fixtures.id("minotaur")])
        XCTAssertTrue(game.players[0].trash.contains(Fixtures.id("screw-lovelorn-fool")))
    }

    func testSpentEffectZetatechAdjustsAGigAndAltMotherDraws() {
        var game = Fixtures.game()
        let unit = game.place("swordwise-huscle", for: 0, gears: ["zetatech-faceplate"])
        game.place("alt-cunningham-mother-of-daemons", for: 0)
        game.setGigs([(6, 3), (8, 5)], for: 0)
        game.spendUnit(0, uid: unit)
        XCTAssertEqual(game.players[0].hand.count, 1)
        XCTAssertNotEqual(game.players[0].gigs.map(\.value), [3, 5])
    }

    func testQuickFightTrickFloorItTurnsATie() {
        var game = Fixtures.game()
        let attacker = game.place("swordwise-huscle", for: 0)
        let defender = game.place("la-llorona-ghost-of-the-past", for: 1)
        game.spendUnit(1, uid: defender)
        game.give(["floor-it"], to: 1)
        game.players[1].eddiesReady = 1
        game.performAttack(0, attackerUid: attacker, target: .unit(defender))
        XCTAssertNil(game.unit(0, attacker))
        XCTAssertNotNil(game.unit(1, defender))
        XCTAssertTrue(game.players[1].trash.contains(Fixtures.id("floor-it")))
    }

    func testQuickReactionTakeControlStopsASingleSteal() {
        var game = Fixtures.game()
        let attacker = game.place("swordwise-huscle", for: 0)
        game.setGigs([(4, 1)], for: 1)
        game.give(["take-control"], to: 1)
        game.players[1].eddiesReady = 2
        game.performAttack(0, attackerUid: attacker, target: .gigs)
        XCTAssertEqual(game.players[1].gigs.count, 1)
        XCTAssertEqual(game.players[1].flags.programsPlayed, 1)
    }

    func testEndOfTurnEffectsKusanagiReturnsAndSandevistanReadies() {
        var game = Fixtures.game()
        let kusanagi = game.place("modded-kusanagi", for: 0)
        let runner = game.place("swordwise-huscle", for: 0, gears: ["sandevistan"])
        game.spendUnit(0, uid: runner)
        game.endTurn(0)
        XCTAssertNil(game.unit(0, kusanagi))
        XCTAssertEqual(game.players[0].hand, [Fixtures.id("modded-kusanagi")])
        XCTAssertEqual(game.unit(0, runner)?.spent, false)
    }

    func testContinuousEffectSaburoBoostsAttackingArasakaOnly() {
        var game = Fixtures.game(legends: [["saburo-arasaka-stubborn-patriarch"], []])
        game.faceUp(0, slot: 0)
        let arasaka = game.place("field-operator", for: 0)
        let other = game.place("swordwise-huscle", for: 0)
        XCTAssertEqual(game.power(0, game.unit(0, arasaka)!, attacking: true), 3)
        XCTAssertEqual(game.power(0, game.unit(0, arasaka)!, attacking: false), 2)
        XCTAssertEqual(game.power(0, game.unit(0, other)!, attacking: true), 3)
    }

    func testContinuousEffectRoyceGainsTwoPerGearOnItsTurn() {
        var game = Fixtures.game(legends: [["royce-psycho-on-the-edge"], []])
        game.faceUp(0, slot: 0)
        game.players[0].legends[0].gears = [Fixtures.id("mantis-blades")]
        XCTAssertEqual(game.legendPower(0, slot: 0), 10)
        game.active = 1
        XCTAssertEqual(game.legendPower(0, slot: 0), 8)
    }

    func testCostModifiersNocturneAndViktor() {
        var game = Fixtures.game()
        let nocturne = Fixtures.id("nocturne-op55-n1")
        XCTAssertEqual(game.effectiveCost(0, nocturne), 3)
        game.players[0].fixer = []
        XCTAssertEqual(game.effectiveCost(0, nocturne), 1)
        game.place("viktor-vektor-drop-your-illusions", for: 0)
        let gorilla = Fixtures.id("gorilla-arms")
        XCTAssertEqual(game.effectiveCost(0, gorilla), 1)
        game.markUsedThisTurn(0, key: Fixtures.id("viktor-vektor-drop-your-illusions") * 16)
        XCTAssertEqual(game.effectiveCost(0, gorilla), 4)
    }

    func testDelayedTriggerSafetyOverrideRetaliatesOnce() {
        var game = Fixtures.game()
        let attacker = game.place("minotaur", for: 0)
        let defender = game.place("swordwise-huscle", for: 1)
        game.spendUnit(1, uid: defender)
        let safety = Fixtures.id("safety-override")
        game.withContext(safety, owner: 1, at: .resolving) { context in
            context.registerDelayed(.lostFight, expiry: .untilYourNextTurn)
        }
        game.performAttack(0, attackerUid: attacker, target: .unit(defender))
        XCTAssertNil(game.unit(1, defender))
        XCTAssertNil(game.unit(0, attacker))
        XCTAssertTrue(game.players[1].flags.delayedTriggers.isEmpty)
    }

    func testLegendCallAndSpendAbilityRiverWard() {
        var game = Fixtures.game(legends: [["river-ward-detective-on-the-hunt", "dum-dum-maelstrom-triggerman"], []])
        game.place("swordwise-huscle", for: 0)
        game.callLegend(0, 1, free: true)
        XCTAssertEqual(game.players[0].hand.count, 1)
        game.faceUp(0, slot: 0)
        game.give(["mantis-blades"], to: 0)
        guard let use = game.abilityUses(0, timing: .mainAction).first else { return XCTFail("pas d'option River Ward") }
        XCTAssertTrue(game.activate(0, use))
        XCTAssertTrue(game.players[0].legends[0].spent)
        XCTAssertEqual(game.players[0].field[0].gears, [Fixtures.id("mantis-blades")])
    }
}
