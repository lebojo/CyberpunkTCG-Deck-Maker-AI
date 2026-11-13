import XCTest
@testable import SimCore

final class RedCardsTests: XCTestCase {
    private func id(_ key: String) -> Int { Fixtures.id(key) }

    private func playProgram(_ key: String, for p: Int = 0, in game: inout Game) {
        game.playProgram(p, id(key), bottomAfter: false)
    }

    private func playFromHand(_ key: String, in game: inout Game, eddies: Int = 9) {
        game.give([key], to: 0)
        game.players[0].eddiesReady = eddies
        XCTAssertTrue(game.playFromHand(0, handIndex: game.players[0].hand.count - 1))
    }

    func testAppetiteForDestructionStealsAGigWhenWinningByThree() {
        var game = Fixtures.game()
        let attacker = game.place("chrome-fang", for: 0)
        let defender = game.place("swordwise-huscle", for: 1)
        game.spendUnit(1, uid: defender)
        game.setGigs([(6, 5), (8, 2)], for: 1)
        playProgram("appetite-for-destruction", in: &game)
        game.performAttack(0, attackerUid: attacker, target: .unit(defender))
        XCTAssertEqual(game.players[0].gigs.count, 1)
        XCTAssertEqual(game.players[1].gigs.count, 1)
        XCTAssertTrue(game.players[0].flags.delayedTriggers.isEmpty)
    }

    func testAppetiteForDestructionIgnoresNarrowWins() {
        var game = Fixtures.game()
        let attacker = game.place("swordwise-huscle", for: 0)
        let defender = game.place("corpo-security", for: 1)
        game.spendUnit(1, uid: defender)
        game.setGigs([(6, 5)], for: 1)
        playProgram("appetite-for-destruction", in: &game)
        game.performAttack(0, attackerUid: attacker, target: .unit(defender))
        XCTAssertTrue(game.players[0].gigs.isEmpty)
        XCTAssertEqual(game.players[0].flags.delayedTriggers.count, 1)
    }

    func testBonnieAndClydeDefeatsTwoUnitsWhenRivalLeadsByTwoGigs() {
        var game = Fixtures.game()
        game.setGigs([(6, 3), (6, 2), (6, 4)], for: 1)
        game.setGigs([(6, 1)], for: 0)
        let small = game.place("corpo-security", for: 1)
        let medium = game.place("swordwise-huscle", for: 1)
        let big = game.place("minotaur", for: 1)
        playProgram("bonnie-and-clyde", in: &game)
        XCTAssertNil(game.unit(1, small))
        XCTAssertNil(game.unit(1, medium))
        XCTAssertNotNil(game.unit(1, big))
    }

    func testBonnieAndClydeDefeatsOneUnitOtherwise() {
        var game = Fixtures.game()
        game.setGigs([(6, 3)], for: 1)
        let small = game.place("corpo-security", for: 1)
        let medium = game.place("swordwise-huscle", for: 1)
        playProgram("bonnie-and-clyde", in: &game)
        XCTAssertEqual(game.players[1].field.count, 1)
        XCTAssertTrue(game.unit(1, small) != nil || game.unit(1, medium) != nil)
    }

    func testCarnageAtTheColosseumCostsLessPerHighGigAndDefeatsAWeakerUnit() {
        var game = Fixtures.game()
        let carnage = id("carnage-at-the-colosseum")
        XCTAssertEqual(game.effectiveCost(0, carnage), 6)
        game.setGigs([(10, 9), (12, 8), (6, 3)], for: 0)
        XCTAssertEqual(game.effectiveCost(0, carnage), 4)
        game.setGigs([(10, 9), (12, 8), (20, 12), (12, 11), (12, 10), (12, 9)], for: 0)
        XCTAssertEqual(game.effectiveCost(0, carnage), 1)
        game.place("swordwise-huscle", for: 0)
        let weak = game.place("corpo-security", for: 1)
        let strong = game.place("minotaur", for: 1)
        playProgram("carnage-at-the-colosseum", in: &game)
        XCTAssertNil(game.unit(1, weak))
        XCTAssertNotNil(game.unit(1, strong))
    }

    func testChromeFangBlocksStealsOfGigsHigherThanTheAttackerPower() {
        var game = Fixtures.game()
        game.setGigs([(8, 5)], for: 0)
        playFromHand("chrome-fang", in: &game)
        let thief = game.place("swordwise-huscle", for: 1)
        game.performAttack(1, attackerUid: thief, target: .gigs)
        XCTAssertEqual(game.players[0].gigs.map(\.value), [5])
        XCTAssertTrue(game.players[1].gigs.isEmpty)
    }

    func testChromeFangStillAllowsStealsOfLowGigs() {
        var game = Fixtures.game()
        game.setGigs([(8, 3)], for: 0)
        playFromHand("chrome-fang", in: &game)
        let thief = game.place("swordwise-huscle", for: 1)
        game.performAttack(1, attackerUid: thief, target: .gigs)
        XCTAssertTrue(game.players[0].gigs.isEmpty)
        XCTAssertEqual(game.players[1].gigs.map(\.value), [3])
    }

    func testDeadmanTransmitterIsDefeatedInsteadOfItsUnit() {
        var game = Fixtures.game()
        let unit = game.place("swordwise-huscle", for: 0, gears: ["deadman-transmitter"])
        game.defeat(0, uid: unit)
        XCTAssertNotNil(game.unit(0, unit))
        XCTAssertEqual(game.unit(0, unit)?.gears, [])
        XCTAssertEqual(game.players[0].trash, [id("deadman-transmitter")])
        game.defeat(0, uid: unit)
        XCTAssertNil(game.unit(0, unit))
    }

    func testDexterDeShawnCallDrawsAndSpendIncreasesAGig() {
        var game = Fixtures.game(legends: [["dexter-deshawn-off-the-grid", "dum-dum-maelstrom-triggerman"], []])
        game.callLegend(0, 0, free: true)
        XCTAssertEqual(game.players[0].hand.count, 1)
        game.setGigs([(10, 3)], for: 0)
        guard let use = game.abilityUses(0, timing: .mainAction).first else { return XCTFail("pas d'option Dexter") }
        XCTAssertTrue(game.activate(0, use))
        XCTAssertTrue(game.players[0].legends[0].spent)
        XCTAssertTrue((4...5).contains(game.players[0].gigs[0].value))
    }

    func testElSombreronPaysTwoToGainMaxGigPower() {
        var game = Fixtures.game()
        let unit = game.place("el-sombrer-n-la-venganza-lenta", for: 0)
        game.setGigs([(8, 8)], for: 0)
        game.setGigs([(4, 1), (6, 2)], for: 1)
        game.players[0].eddiesReady = 2
        game.performAttack(0, attackerUid: unit, target: .gigs)
        XCTAssertEqual(game.players[0].gigs.count, 3)
        XCTAssertEqual(game.players[0].eddiesReady, 0)
    }

    func testElSombreronDoesNothingWithoutMana() {
        var game = Fixtures.game()
        let unit = game.place("el-sombrer-n-la-venganza-lenta", for: 0)
        game.setGigs([(8, 8)], for: 0)
        game.setGigs([(4, 1), (6, 2)], for: 1)
        game.performAttack(0, attackerUid: unit, target: .gigs)
        XCTAssertEqual(game.players[0].gigs.count, 2)
    }

    func testGunpointDiplomacyGivesBothEffectsWithMoreStreetCred() {
        var game = Fixtures.game()
        let unit = game.place("swordwise-huscle", for: 0)
        game.setGigs([(6, 5)], for: 0)
        playProgram("gunpoint-diplomacy", in: &game)
        let target = game.unit(0, unit)!
        XCTAssertEqual(game.power(0, target, attacking: false), 6)
        XCTAssertTrue(game.keywords(0, target).contains(.canAttackReadyUnits))
    }

    func testGunpointDiplomacyGivesOnlyOneEffectWithLessStreetCred() {
        var game = Fixtures.game()
        let unit = game.place("swordwise-huscle", for: 0)
        game.setGigs([(6, 1)], for: 0)
        game.setGigs([(6, 5)], for: 1)
        playProgram("gunpoint-diplomacy", in: &game)
        let target = game.unit(0, unit)!
        let pumped = game.power(0, target, attacking: false) == 6
        let readyHunter = game.keywords(0, target).contains(.canAttackReadyUnits)
        XCTAssertNotEqual(pumped, readyHunter)
    }

    func testJapantownJoninPumpsAFriendlyUnit() {
        var game = Fixtures.game()
        let unit = game.place("swordwise-huscle", for: 0)
        playFromHand("japantown-jonin", in: &game)
        XCTAssertEqual(game.power(0, game.unit(0, unit)!, attacking: false), 5)
    }

    func testJohnnySilverhandLetsAFreshUnitAttackSpentUnitsAndPumpsRockers() {
        var game = Fixtures.game(legends: [["johnny-silverhand-rocking-renegade"], []])
        game.faceUp(0, slot: 0)
        let rocker = game.place("kerry-eurodyne-the-last-rockerboy", for: 0, ready: false)
        let target = game.place("swordwise-huscle", for: 1)
        game.spendUnit(1, uid: target)
        game.setGigs([(10, 9)], for: 0)
        game.players[0].eddiesReady = 1
        XCTAssertFalse(game.canAttackAtAll(0, game.unit(0, rocker)!))
        guard let use = game.abilityUses(0, timing: .mainAction).first else { return XCTFail("pas d'option Johnny") }
        XCTAssertTrue(game.activate(0, use))
        let unit = game.unit(0, rocker)!
        XCTAssertTrue(game.canAttackAtAll(0, unit))
        XCTAssertEqual(game.power(0, unit, attacking: true), 7)
        XCTAssertTrue(game.players[0].legends[0].spent)
        XCTAssertEqual(game.players[0].eddiesReady, 0)
    }

    func testJohnnySilverhandKeepsTheLegendReadyWhenItCannotPay() {
        var game = Fixtures.game(legends: [["johnny-silverhand-rocking-renegade"], []])
        game.faceUp(0, slot: 0)
        let rocker = game.place("kerry-eurodyne-the-last-rockerboy", for: 0, ready: false)
        let option = AbilityOption(ability: 0, target: .unit(owner: 0, uid: rocker), value: 30, eddieCost: 2)
        let use = AbilityUse(source: .legend(slot: 0), cardId: id("johnny-silverhand-rocking-renegade"), option: option)
        game.players[0].eddiesReady = 1
        XCTAssertFalse(game.activate(0, use))
        XCTAssertFalse(game.players[0].legends[0].spent)
        XCTAssertEqual(game.players[0].eddiesReady, 1)
    }

    func testVRoamerDoesNotDrawAtTheEndOfTheRivalTurn() {
        var game = Fixtures.game()
        game.place("v-roamer-of-the-badlands", for: 0)
        game.setGigs([(10, 9), (10, 8)], for: 0)
        game.endTurn(1)
        XCTAssertTrue(game.players[0].hand.isEmpty)
    }

    func testKerryEurodyneDrawsTwoOnlyWithAHighGig() {
        var game = Fixtures.game()
        let kerry = game.place("kerry-eurodyne-the-last-rockerboy", for: 0, ready: false)
        game.setGigs([(10, 7)], for: 0)
        XCTAssertTrue(game.abilityUses(0, timing: .mainAction).isEmpty)
        game.setGigs([(10, 9)], for: 0)
        guard let use = game.abilityUses(0, timing: .mainAction).first else { return XCTFail("pas d'option Kerry") }
        XCTAssertTrue(game.activate(0, use))
        XCTAssertEqual(game.players[0].hand.count, 2)
        XCTAssertEqual(game.unit(0, kerry)?.spent, true)
    }

    func testOctantCostsLessPerHighGigWithAMinimumOfOne() {
        var game = Fixtures.game()
        let octant = id("octant")
        XCTAssertEqual(game.effectiveCost(0, octant), 7)
        game.setGigs([(10, 9), (12, 8)], for: 0)
        XCTAssertEqual(game.effectiveCost(0, octant), 5)
        game.setGigs(Array(repeating: (sides: 12, value: 12), count: 8), for: 0)
        XCTAssertEqual(game.effectiveCost(0, octant), 1)
    }

    func testRoyceDefeatsAPowerThreeUnitOnlyWithMoreStreetCred() {
        var game = Fixtures.game()
        let victim = game.place("swordwise-huscle", for: 1)
        playFromHand("royce-don-t-call-me-simon", in: &game)
        XCTAssertNotNil(game.unit(1, victim))
        game.setGigs([(6, 4)], for: 0)
        playFromHand("royce-don-t-call-me-simon", in: &game)
        XCTAssertNil(game.unit(1, victim))
    }

    func testShatteredMemoriesRefillsBothHandsAndDrawsTwoOnAMatchingGig() {
        var game = Fixtures.game()
        game.setGigs([(6, 5)], for: 0)
        game.give(Array(repeating: Fixtures.filler, count: 3), to: 0)
        game.give(Array(repeating: Fixtures.filler, count: 2), to: 1)
        playProgram("shattered-memories", in: &game)
        XCTAssertEqual(game.players[0].hand.count, 7)
        XCTAssertEqual(game.players[1].hand.count, 5)
        XCTAssertEqual(game.players[0].trash.count, 4)
        XCTAssertEqual(game.players[1].trash.count, 2)
    }

    func testShatteredMemoriesDoesNotDrawExtraWithoutAMatch() {
        var game = Fixtures.game()
        game.setGigs([(6, 4)], for: 0)
        game.give(Array(repeating: Fixtures.filler, count: 3), to: 0)
        game.give(Array(repeating: Fixtures.filler, count: 2), to: 1)
        playProgram("shattered-memories", in: &game)
        XCTAssertEqual(game.players[0].hand.count, 5)
    }

    func testVRoamerRaisesAStolenGigAndDrawsWithTwoHighGigs() {
        var game = Fixtures.game()
        let roamer = game.place("v-roamer-of-the-badlands", for: 0)
        game.setGigs([(6, 2)], for: 1)
        game.performAttack(0, attackerUid: roamer, target: .gigs)
        XCTAssertEqual(game.players[0].gigs.count, 1)
        XCTAssertGreaterThan(game.players[0].gigs[0].value, 2)
        game.setGigs([(10, 9), (10, 8)], for: 0)
        game.endTurn(0)
        XCTAssertEqual(game.players[0].hand.count, 1)
    }

    func testYorinobuPlaysAFreeUnitAndDrawsOnceForArasakaDefeats() {
        var game = Fixtures.game()
        game.players[0].trash = [id("maxtac-squadron")]
        game.give(["swordwise-huscle"], to: 0)
        playFromHand("yorinobu-arasaka-steel-dragon", in: &game)
        XCTAssertEqual(game.players[0].field.count, 2)
        XCTAssertTrue(game.players[0].trash.isEmpty)
        let fresh = game.players[0].field[1]
        XCTAssertTrue(game.keywords(0, fresh).contains(.attacksUnitsWhenPlayed))
        let first = game.place("field-operator", for: 0)
        let second = game.place("field-operator", for: 0)
        let handBefore = game.players[0].hand.count
        game.defeat(0, uid: first)
        game.defeat(0, uid: second)
        XCTAssertEqual(game.players[0].hand.count, handBefore + 1)
    }

    func testVStreetkidRetrievesOnlyOneCopyOfTheBraindanceProgram() {
        var game = Fixtures.game(legends: [["v-streetkid"], []])
        game.players[0].trash = [id("bonnie-and-clyde"), id("bonnie-and-clyde")]
        game.callLegend(0, 0, free: true)
        XCTAssertEqual(game.players[0].hand, [id("bonnie-and-clyde")])
        XCTAssertEqual(game.players[0].trash.filter { $0 == id("bonnie-and-clyde") }.count, 1)
    }

    private func alterRivalGig(in game: inout Game) {
        game.withContext(id("floor-it"), owner: 0, at: .resolving) { context in
            context.swapGigs(mine: 0, theirs: 0)
        }
    }

    func testMeredithStoutEveryCopyRecoversACardWhenARivalSwapsAGig() {
        var game = Fixtures.game()
        game.setGigs([(6, 2)], for: 0)
        game.setGigs([(6, 4)], for: 1)
        game.place("meredith-stout-stone-cold-corpo", for: 1)
        game.place("meredith-stout-stone-cold-corpo", for: 1)
        game.players[1].trash = [id("minotaur"), id("floor-it"), id("octant")]
        alterRivalGig(in: &game)
        XCTAssertEqual(game.players[1].hand.count, 2)
        XCTAssertEqual(game.players[1].trash.count, 1)
    }

    func testMeredithStoutSingleCopyRecoversOneCard() {
        var game = Fixtures.game()
        game.setGigs([(6, 2)], for: 0)
        game.setGigs([(6, 4)], for: 1)
        game.place("meredith-stout-stone-cold-corpo", for: 1)
        game.players[1].trash = [id("minotaur"), id("floor-it")]
        alterRivalGig(in: &game)
        XCTAssertEqual(game.players[1].hand.count, 1)
    }
}
