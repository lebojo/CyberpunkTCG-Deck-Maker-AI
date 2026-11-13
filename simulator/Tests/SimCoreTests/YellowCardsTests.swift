import XCTest
@testable import SimCore

final class YellowCardsTests: XCTestCase {
    private func play(_ key: String, in game: inout Game, eddies: Int = 10) {
        game.give([key], to: 0)
        game.players[0].eddiesReady = eddies
        XCTAssertTrue(game.playFromHand(0, handIndex: game.players[0].hand.count - 1))
    }

    func testAdamSmasherDefeatsEveryOtherUnit() {
        var game = Fixtures.game()
        game.place("swordwise-huscle", for: 0)
        game.place("corpo-security", for: 1)
        game.place("minotaur", for: 1)
        play("adam-smasher-metal-over-meat", in: &game)
        XCTAssertEqual(game.players[0].field.map(\.cardId), [Fixtures.id("adam-smasher-metal-over-meat")])
        XCTAssertTrue(game.players[1].field.isEmpty)
    }

    func testCaliberPlayDefeatsOnlyACheapRivalUnit() {
        var game = Fixtures.game()
        let cheap = game.place("corpo-security", for: 1)
        let costly = game.place("swordwise-huscle", for: 1)
        play("caliber-totentanz-s-top-dog", in: &game)
        XCTAssertNil(game.unit(1, cheap))
        XCTAssertNotNil(game.unit(1, costly))
    }

    func testCaliberDefeatedDiscardsTwoWhenCostMatchesAGig() {
        var game = Fixtures.game()
        let caliber = game.place("caliber-totentanz-s-top-dog", for: 0)
        game.setGigs([(6, 2)], for: 0)
        game.give(["riot-shield", "corpo-security", "swordwise-huscle"], to: 1)
        game.defeat(0, uid: caliber)
        XCTAssertEqual(game.players[1].hand.count, 1)
    }

    func testCaliberDefeatedDiscardsOneWhenCostDoesNotMatch() {
        var game = Fixtures.game()
        let caliber = game.place("caliber-totentanz-s-top-dog", for: 0)
        game.setGigs([(6, 5)], for: 0)
        game.give(["riot-shield", "corpo-security"], to: 1)
        game.defeat(0, uid: caliber)
        XCTAssertEqual(game.players[1].hand.count, 1)
    }

    func testGildedMatonTradesAGearForACheapRivalUnit() {
        var game = Fixtures.game()
        let ally = game.place("minotaur", for: 0, gears: ["mantis-blades"])
        let target = game.place("swordwise-huscle", for: 1)
        play("gilded-mat-n", in: &game)
        XCTAssertEqual(game.unit(0, ally)?.gears, [])
        XCTAssertNil(game.unit(1, target))
    }

    func testGildedMatonDoesNothingWithoutAGear() {
        var game = Fixtures.game()
        let target = game.place("swordwise-huscle", for: 1)
        play("gilded-mat-n", in: &game)
        XCTAssertNotNil(game.unit(1, target))
    }

    func testGildedMatonPicksTheValidGearAndTargetPair() {
        var game = Fixtures.game()
        let ally = game.place("minotaur", for: 0, gears: ["sandevistan"])
        let cheap = game.place("ruthless-lowlife", for: 1)
        let fit = game.place("swordwise-huscle", for: 1)
        play("gilded-mat-n", in: &game)
        XCTAssertEqual(game.unit(0, ally)?.gears, [])
        XCTAssertNil(game.unit(1, fit))
        XCTAssertNotNil(game.unit(1, cheap))
    }

    func testGildedMatonPlayValueIgnoresTheTargetBonusWithoutAFriendlyGear() {
        var game = Fixtures.game()
        game.place("swordwise-huscle", for: 1)
        let card = Fixtures.id("gilded-mat-n")
        let without = game.implementation(card).playValue(in: game.query(card, owner: 0, at: .hand))
        game.place("minotaur", for: 0, gears: ["mantis-blades"])
        let with = game.implementation(card).playValue(in: game.query(card, owner: 0, at: .hand))
        XCTAssertEqual((with ?? 0) - (without ?? 0), 3)
    }

    func testHanakoTakesCardsMatchingGigValuesAndBottomsTheRest() {
        var game = Fixtures.game()
        game.setGigs([(6, 2)], for: 0)
        let filler = Array(repeating: Fixtures.filler, count: 6)
        game.players[0].deck = (filler + ["swordwise-huscle", "mantis-blades", "riot-shield", "corpo-security"]).map { Fixtures.id($0) }
        play("hanako-arasaka-in-a-gilded-cage", in: &game)
        XCTAssertEqual(game.players[0].hand.sorted(), [Fixtures.id("riot-shield"), Fixtures.id("corpo-security")].sorted())
        XCTAssertEqual(game.players[0].deck.count, 8)
    }

    func testHeywoodDefeatsAGearAndDrawsOnMatchingCost() {
        var game = Fixtures.game()
        game.setGigs([(6, 2)], for: 0)
        let rival = game.place("swordwise-huscle", for: 1, gears: ["riot-shield"])
        play("heywood-ripperdoc", in: &game)
        XCTAssertEqual(game.unit(1, rival)?.gears, [])
        XCTAssertEqual(game.players[0].hand.count, 1)
    }

    func testHeywoodDoesNotDrawWhenCostDiffers() {
        var game = Fixtures.game()
        game.setGigs([(6, 5)], for: 0)
        let rival = game.place("swordwise-huscle", for: 1, gears: ["riot-shield"])
        play("heywood-ripperdoc", in: &game)
        XCTAssertEqual(game.unit(1, rival)?.gears, [])
        XCTAssertTrue(game.players[0].hand.isEmpty)
    }

    func testJackieGainsPowerPerEvenGigWhenAttacking() {
        var game = Fixtures.game()
        let jackie = game.place("jackie-welles-ride-or-die-choom", for: 0)
        game.setGigs([(6, 2), (6, 4), (6, 3)], for: 0)
        game.setGigs([(6, 3)], for: 1)
        game.performAttack(0, attackerUid: jackie, target: .gigs)
        XCTAssertEqual(game.power(0, game.unit(0, jackie)!, attacking: false), 12)
    }

    func testJackieDefeatedDrawsPerOddGig() {
        var game = Fixtures.game()
        let jackie = game.place("jackie-welles-ride-or-die-choom", for: 0)
        game.setGigs([(6, 2), (6, 3), (6, 5)], for: 0)
        game.defeat(0, uid: jackie)
        XCTAssertEqual(game.players[0].hand.count, 2)
    }

    func testKerryDrawsThreeOnAMaxRollOnAD20() {
        var game = Fixtures.game(legends: [["kerry-eurodyne-axe-attitude-audience"], []])
        game.faceUp(0, slot: 0)
        game.setGigs([(20, 20)], for: 0)
        game.broadcast(.gigRolled(index: 0), to: 0)
        XCTAssertEqual(game.players[0].hand.count, 3)
        XCTAssertEqual(game.players[0].gigs[0].value, 20)
    }

    func testKerryKeepsAGoodRollAndDrawsNothingOnAMiddleValue() {
        var game = Fixtures.game(legends: [["kerry-eurodyne-axe-attitude-audience"], []])
        game.faceUp(0, slot: 0)
        game.setGigs([(6, 4)], for: 0)
        game.broadcast(.gigRolled(index: 0), to: 0)
        XCTAssertTrue(game.players[0].hand.isEmpty)
        XCTAssertEqual(game.players[0].gigs[0].value, 4)
    }

    func testLiveWithTheAftermathEachPlayerDefeatsOneUnit() {
        var game = Fixtures.game()
        game.place("corpo-security", for: 0)
        game.place("swordwise-huscle", for: 0)
        game.place("corpo-security", for: 1)
        game.place("minotaur", for: 1)
        play("live-with-the-aftermath", in: &game)
        XCTAssertEqual(game.players[0].field.count, 1)
        XCTAssertEqual(game.players[1].field.count, 1)
    }

    func testMaxTacStopsRivalUnitsFromAttackingTheTurnTheyArePlayed() {
        var game = Fixtures.game()
        game.setGigs([(6, 3)], for: 0)
        let fast = game.place("modded-kusanagi", for: 1, ready: false)
        XCTAssertTrue(game.canAttackAtAll(1, game.unit(1, fast)!))
        game.place("maxtac-suppression-team", for: 0)
        XCTAssertFalse(game.canAttackAtAll(1, game.unit(1, fast)!))
        let veteran = game.place("modded-kusanagi", for: 1)
        XCTAssertTrue(game.canAttackAtAll(1, game.unit(1, veteran)!))
    }

    func testMuamarProtectsAUnitFromDefeatInAFight() {
        var game = Fixtures.game(legends: [["muamar-reyes-el-capit-n"], []])
        let protected = game.place("corpo-security", for: 0)
        game.spendUnit(0, uid: protected)
        game.withContext(Fixtures.id("muamar-reyes-el-capit-n"), owner: 0, at: .legend(slot: 0)) { context in
            context.registerDelayed(.wouldBeDefeated, expiry: .endOfTurn, payload: protected)
        }
        let attacker = game.place("swordwise-huscle", for: 1)
        game.performAttack(1, attackerUid: attacker, target: .unit(protected))
        XCTAssertNotNil(game.unit(0, protected))
    }

    func testMuamarCallResolvesOneOfItsTwoEffects() {
        var game = Fixtures.game(legends: [["muamar-reyes-el-capit-n"], []])
        game.place("swordwise-huscle", for: 0)
        game.callLegend(0, 0, free: true)
        let drew = game.players[0].hand.count == 1
        let protected = game.players[0].flags.delayedTriggers.count == 1
        XCTAssertTrue(drew != protected)
    }

    func testMuamarSpendAdjustsAGig() {
        var game = Fixtures.game(legends: [["muamar-reyes-el-capit-n"], []])
        game.faceUp(0, slot: 0)
        game.setGigs([(6, 3), (6, 4)], for: 0)
        let before = game.players[0].gigs.map(\.value)
        guard let use = game.abilityUses(0, timing: .mainAction).first else { return XCTFail("no Muamar option") }
        XCTAssertTrue(game.activate(0, use))
        XCTAssertTrue(game.players[0].legends[0].spent)
        XCTAssertNotEqual(game.players[0].gigs.map(\.value), before)
    }

    func testRogueDrawsOnAnEvenStolenGigAsASoloLegend() {
        var game = Fixtures.game()
        let rogue = soloLegend("rogue-amendiares-preem-solo", for: 0, in: &game)
        game.setGigs([(6, 2)], for: 1)
        game.performAttack(0, attackerUid: rogue, target: .gigs)
        XCTAssertEqual(game.players[0].hand.count, 1)
    }

    func testRogueMakesTheRivalDiscardOnAnOddStolenGig() {
        var game = Fixtures.game()
        let rogue = soloLegend("rogue-amendiares-preem-solo", for: 0, in: &game)
        game.setGigs([(6, 3)], for: 1)
        game.give(["corpo-security"], to: 1)
        game.performAttack(0, attackerUid: rogue, target: .gigs)
        XCTAssertTrue(game.players[1].hand.isEmpty)
        XCTAssertTrue(game.players[0].hand.isEmpty)
    }

    func testRogueIgnoresGigsStolenByNonLegendUnits() {
        var game = Fixtures.game(legends: [["rogue-amendiares-preem-solo"], []])
        game.faceUp(0, slot: 0)
        let attacker = game.place("swordwise-huscle", for: 0)
        game.setGigs([(6, 2)], for: 1)
        game.performAttack(0, attackerUid: attacker, target: .gigs)
        XCTAssertTrue(game.players[0].hand.isEmpty)
    }

    func testTBugCallsAFaceDownLegendForFreeWhenDefeated() {
        var game = Fixtures.game(legends: [["dum-dum-maelstrom-triggerman"], []])
        let bug = game.place("t-bug-amateur-philosopher", for: 0)
        game.defeat(0, uid: bug)
        XCTAssertTrue(game.players[0].legends[0].faceUp)
        XCTAssertEqual(game.players[0].eddiesReady, 0)
    }

    func testTBugCannotCallASecondLegendInTheSameTurn() {
        var game = Fixtures.game(legends: [["dum-dum-maelstrom-triggerman"], []])
        game.players[0].flags.called = true
        let bug = game.place("t-bug-amateur-philosopher", for: 0)
        game.defeat(0, uid: bug)
        XCTAssertFalse(game.players[0].legends[0].faceUp)
    }

    func testTBugCallsExactlyOneOfTwoFaceDownLegends() {
        var game = Fixtures.game(legends: [["dum-dum-maelstrom-triggerman", "river-ward-detective-on-the-hunt"], []])
        let bug = game.place("t-bug-amateur-philosopher", for: 0)
        game.defeat(0, uid: bug)
        XCTAssertEqual(game.players[0].legends.filter(\.faceUp).count, 1)
    }

    func testTraumaTeamCostDropsWithUnitsInTrashDownToOne() {
        var game = Fixtures.game()
        let team = Fixtures.id("trauma-team-operatives")
        XCTAssertEqual(game.effectiveCost(0, team), 6)
        game.players[0].trash = Array(repeating: Fixtures.id("corpo-security"), count: 3) + [Fixtures.id("mantis-blades")]
        XCTAssertEqual(game.effectiveCost(0, team), 3)
        game.players[0].trash = Array(repeating: Fixtures.id("corpo-security"), count: 9)
        XCTAssertEqual(game.effectiveCost(0, team), 1)
    }

    func testViktorPinchEquipsACheapCyberwareFromTrashToAnotherUnit() {
        var game = Fixtures.game()
        let ally = game.place("minotaur", for: 0)
        game.players[0].trash = ["riot-shield", "mantis-blades"].map { Fixtures.id($0) }
        play("viktor-vektor-you-might-feel-a-little-pinch", in: &game)
        XCTAssertEqual(game.unit(0, ally)?.gears, [Fixtures.id("mantis-blades")])
        XCTAssertEqual(game.players[0].trash, [Fixtures.id("riot-shield")])
    }

    func testViktorPinchLeavesTheGearWithoutAnotherUnit() {
        var game = Fixtures.game()
        game.players[0].trash = [Fixtures.id("mantis-blades")]
        play("viktor-vektor-you-might-feel-a-little-pinch", in: &game)
        XCTAssertEqual(game.players[0].trash, [Fixtures.id("mantis-blades")])
    }

    func testHeistKeepsEveryUnchosenCardWhenTwoGearsAreIdentical() {
        var game = Fixtures.game()
        let blades = Fixtures.id("mantis-blades")
        let filler = Fixtures.id(Fixtures.filler)
        game.players[0].deck = Array(repeating: filler, count: 6) + [filler, blades, blades, filler]
        game.give(["the-heist"], to: 0)
        game.players[0].eddiesReady = 2
        XCTAssertTrue(game.playFromHand(0, handIndex: 0))
        XCTAssertEqual(game.players[0].hand.filter { $0 == blades }.count + game.players[0].field.flatMap(\.gears).filter { $0 == blades }.count, 1)
        XCTAssertEqual(game.players[0].trash.filter { $0 == blades }.count, 1)
        XCTAssertEqual(game.players[0].trash.filter { $0 == filler }.count, 2)
        XCTAssertEqual(game.players[0].deck.count, 6)
    }

    func testRiverWardKeepsOneOfTwoIdenticalCardsOnTop() {
        var game = Fixtures.game(legends: [["river-ward-detective-on-the-hunt"], []])
        game.faceUp(0, slot: 0)
        let filler = Fixtures.id(Fixtures.filler)
        game.players[0].deck = Array(repeating: filler, count: 10)
        let unit = game.place("swordwise-huscle", for: 0, gears: ["mantis-blades"])
        game.defeat(0, uid: unit)
        XCTAssertEqual(game.players[0].deck.count, 9)
        XCTAssertEqual(game.players[0].trash.filter { $0 == filler }.count, 1)
    }

    func testCyberpsychosisDoesNotDefeatAUnitThatNeitherStoleNorFought() {
        var game = Fixtures.game()
        let unit = game.place("minotaur", for: 0, gears: ["mantis-blades", "kiroshi-optics"])
        activateCyberpsychosis(on: unit, in: &game)
        game.endTurn(0)
        XCTAssertNotNil(game.unit(0, unit))
    }

    func testCyberpsychosisDefeatsAUnitThatStoleAtTheEndOfTheTurn() {
        var game = Fixtures.game()
        let unit = game.place("minotaur", for: 0, gears: ["mantis-blades", "kiroshi-optics"])
        game.setGigs([(6, 3)], for: 1)
        activateCyberpsychosis(on: unit, in: &game)
        game.performAttack(0, attackerUid: unit, target: .gigs)
        XCTAssertNotNil(game.unit(0, unit))
        game.endTurn(0)
        XCTAssertNil(game.unit(0, unit))
    }

    func testCyberpsychosisDefeatsAUnitThatFoughtAtTheEndOfTheTurn() {
        var game = Fixtures.game()
        let unit = game.place("minotaur", for: 0, gears: ["mantis-blades", "kiroshi-optics"])
        let target = game.place("corpo-security", for: 1)
        game.spendUnit(1, uid: target)
        activateCyberpsychosis(on: unit, in: &game)
        game.performAttack(0, attackerUid: unit, target: .unit(target))
        XCTAssertNil(game.unit(1, target))
        game.endTurn(0)
        XCTAssertNil(game.unit(0, unit))
    }

    func testCyberpsychosisTriggersOnADrawnFight() {
        var game = Fixtures.game()
        let unit = game.place("minotaur", for: 0, gears: ["mantis-blades", "kiroshi-optics"])
        let target = game.place("corpo-security", for: 1)
        game.spendUnit(1, uid: target)
        activateCyberpsychosis(on: unit, in: &game)
        let attackPower = game.power(0, game.unit(0, unit)!, attacking: true)
        let index = game.players[1].field.firstIndex { $0.uid == target }!
        game.players[1].field[index].bonusPower = attackPower - game.power(1, game.players[1].field[index], attacking: false)
        game.performAttack(0, attackerUid: unit, target: .unit(target))
        XCTAssertTrue(game.players[0].flags.delayedTriggers.isEmpty)
        XCTAssertNil(game.unit(1, target))
        XCTAssertNil(game.unit(0, unit))
    }

    private func activateCyberpsychosis(on uid: Int, in game: inout Game) {
        let card = Fixtures.id("cyberpsychosis")
        game.give(["cyberpsychosis"], to: 0)
        game.players[0].eddiesReady = 3
        let option = AbilityOption(ability: 0, target: .unit(owner: 0, uid: uid), eddieCost: 3)
        XCTAssertTrue(game.activate(0, AbilityUse(source: .hand(cardId: card), cardId: card, option: option)))
    }

    private func soloLegend(_ key: String, for p: Int, in game: inout Game) -> Int {
        let uid = game.takeUid()
        var unit = FieldUnit(uid: uid, cardId: Fixtures.id(key), isLegend: true)
        unit.lagging = false
        game.players[p].field.append(unit)
        return uid
    }
}
