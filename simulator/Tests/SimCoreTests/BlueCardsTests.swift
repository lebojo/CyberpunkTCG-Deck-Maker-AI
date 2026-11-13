import XCTest
@testable import SimCore

final class BlueCardsTests: XCTestCase {
    private func id(_ key: String) -> Int { Fixtures.id(key) }

    private func playFromHand(_ game: inout Game, _ key: String, for p: Int = 0, eddies: Int = 10) {
        game.players[p].eddiesReady = eddies
        game.give([key], to: p)
        let index = game.players[p].hand.count - 1
        XCTAssertTrue(game.playFromHand(p, handIndex: index))
    }

    func testDelamainCabReadiesAnEddieAfterStealing() {
        var game = Fixtures.game()
        let cab = game.place("delamain-cab", for: 0)
        game.setGigs([(6, 3)], for: 1)
        game.players[0].eddiesReady = 0
        game.players[0].eddiesSpent = 2
        game.performAttack(0, attackerUid: cab, target: .gigs)
        game.endTurn(0)
        XCTAssertEqual(game.players[0].eddiesReady, 1)
    }

    func testDelamainCabDoesNothingWithoutAStealThisTurn() {
        var game = Fixtures.game()
        game.place("delamain-cab", for: 0)
        game.players[0].eddiesReady = 0
        game.players[0].eddiesSpent = 2
        game.endTurn(0)
        XCTAssertEqual(game.players[0].eddiesReady, 0)
    }

    func testDelamainRideshareAIDrawsTwo() {
        var game = Fixtures.game()
        playFromHand(&game, "delamain-rideshare-ai")
        XCTAssertEqual(game.players[0].hand.count, 2)
    }

    func testEvelynLegendReadiesAnEddieWhenACorpoUnitSteals() {
        var game = Fixtures.game(legends: [["evelyn-parker-beautiful-enigma"], []])
        game.faceUp(0, slot: 0)
        let corpo = game.place("field-operator", for: 0)
        game.setGigs([(6, 3)], for: 1)
        game.players[0].eddiesReady = 0
        game.players[0].eddiesSpent = 2
        game.performAttack(0, attackerUid: corpo, target: .gigs)
        XCTAssertEqual(game.players[0].eddiesReady, 1)
    }

    func testEvelynLegendIgnoresNonCorpoOrGangerThieves() {
        var game = Fixtures.game(legends: [["evelyn-parker-beautiful-enigma"], []])
        game.faceUp(0, slot: 0)
        let merc = game.place("swordwise-huscle", for: 0)
        game.setGigs([(6, 3)], for: 1)
        game.players[0].eddiesReady = 0
        game.players[0].eddiesSpent = 2
        game.performAttack(0, attackerUid: merc, target: .gigs)
        XCTAssertEqual(game.players[0].eddiesReady, 0)
    }

    func testEvelynLegendForcesARivalUnitToAttack() {
        var game = Fixtures.game(legends: [["evelyn-parker-beautiful-enigma"], []])
        game.faceUp(0, slot: 0)
        game.place("corpo-security", for: 0)
        let rival = game.place("swordwise-huscle", for: 1, ready: true)
        game.players[0].eddiesReady = 3
        guard let use = game.abilityUses(0, timing: .mainAction).first else { return XCTFail("no Evelyn option") }
        XCTAssertTrue(game.activate(0, use))
        XCTAssertEqual(game.unit(1, rival)?.mustAttackOnTurn, game.turn + 1)
        XCTAssertTrue(game.players[0].legends[0].spent)
    }

    func testEvelynSirenDrawsOnAttack() {
        var game = Fixtures.game()
        let siren = game.place("evelyn-parker-scheming-siren", for: 0)
        game.setGigs([(6, 3)], for: 1)
        game.performAttack(0, attackerUid: siren, target: .gigs)
        XCTAssertEqual(game.players[0].hand.count, 1)
        XCTAssertEqual(game.players[1].gigs.count, 1)
    }

    func testEvelynSirenDiscardsWhenAheadOnStreetCred() {
        var game = Fixtures.game()
        let siren = game.place("evelyn-parker-scheming-siren", for: 0)
        game.setGigs([(6, 4)], for: 0)
        game.setGigs([(6, 1)], for: 1)
        game.performAttack(0, attackerUid: siren, target: .gigs)
        XCTAssertEqual(game.players[0].hand.count, 0)
        XCTAssertEqual(game.players[0].trash.count, 1)
    }

    func testHackedCorpoTrashesThreeAndTakesAProgram() {
        var game = Fixtures.game(decks: [["corpo-security", "corpo-security", "corpo-security", "trust-no-one", "corpo-security", "floor-it"], []])
        playFromHand(&game, "hacked-corpo")
        XCTAssertEqual(game.players[0].hand.count, 1)
        XCTAssertEqual(game.data(game.players[0].hand[0]).kind, .program)
        XCTAssertEqual(game.players[0].trash.count, 2)
        XCTAssertEqual(game.players[0].deck.count, 3)
    }

    func testHackedCorpoWithoutProgramJustTrashes() {
        var game = Fixtures.game()
        playFromHand(&game, "hacked-corpo")
        XCTAssertTrue(game.players[0].hand.isEmpty)
        XCTAssertEqual(game.players[0].trash.count, 3)
    }

    func testJudyLegendBoostsAnAllyWhenPlayingABraindance() {
        var game = Fixtures.game(legends: [["judy-lvarez-braindance-maestro"], []])
        game.faceUp(0, slot: 0)
        let unit = game.place("swordwise-huscle", for: 0)
        game.setGigs([(6, 5)], for: 0)
        playFromHand(&game, "trust-no-one")
        XCTAssertEqual(game.power(0, game.unit(0, unit)!, attacking: false), 4)
    }

    func testJudyLegendIgnoresOtherPrograms() {
        var game = Fixtures.game(legends: [["judy-lvarez-braindance-maestro"], []])
        game.faceUp(0, slot: 0)
        let unit = game.place("swordwise-huscle", for: 0)
        game.place("la-llorona-ghost-of-the-past", for: 1)
        playFromHand(&game, "floor-it")
        XCTAssertEqual(game.power(0, game.unit(0, unit)!, attacking: false), 3)
    }

    func testJudyLegendSpendTrashesTopAndTakesAProgram() {
        var game = Fixtures.game(legends: [["judy-lvarez-braindance-maestro"], []], decks: [["corpo-security", "floor-it"], []])
        game.faceUp(0, slot: 0)
        guard let use = game.abilityUses(0, timing: .mainAction).first else { return XCTFail("no Judy option") }
        XCTAssertTrue(game.activate(0, use))
        XCTAssertEqual(game.players[0].hand, [id("floor-it")])
        XCTAssertTrue(game.players[0].legends[0].spent)
        XCTAssertTrue(game.players[0].trash.isEmpty)
    }

    func testJudyLegendSpendKeepsNonProgramInTrash() {
        var game = Fixtures.game(legends: [["judy-lvarez-braindance-maestro"], []], decks: [["floor-it", "corpo-security"], []])
        game.faceUp(0, slot: 0)
        guard let use = game.abilityUses(0, timing: .mainAction).first else { return XCTFail("no Judy option") }
        XCTAssertTrue(game.activate(0, use))
        XCTAssertTrue(game.players[0].hand.isEmpty)
        XCTAssertEqual(game.players[0].trash, [id("corpo-security")])
    }

    func testJudyUnitPlaysTheTopCardForFree() {
        var game = Fixtures.game(decks: [["floor-it", "field-operator"], []])
        let judy = game.place("judy-lvarez-nothing-to-doubt", for: 0)
        game.players[0].eddiesReady = 1
        guard let use = game.abilityUses(0, timing: .mainAction).first else { return XCTFail("no Judy option") }
        XCTAssertTrue(game.activate(0, use))
        XCTAssertEqual(game.unit(0, judy)?.spent, true)
        XCTAssertEqual(game.players[0].field.count, 2)
        XCTAssertEqual(game.players[0].eddiesReady, 0)
    }

    func testJudyUnitAddsAnUnplayableCardToHand() {
        var game = Fixtures.game(decks: [["corpo-security", "floor-it"], []])
        game.place("judy-lvarez-nothing-to-doubt", for: 0)
        game.players[0].eddiesReady = 1
        guard let use = game.abilityUses(0, timing: .mainAction).first else { return XCTFail("no Judy option") }
        XCTAssertTrue(game.activate(0, use))
        XCTAssertEqual(game.players[0].hand, [id("floor-it")])
        XCTAssertEqual(game.players[0].field.count, 1)
    }

    func testLucynaDrawsOneOrTwoDependingOnMinGigs() {
        var game = Fixtures.game(legends: [["lucyna-kushinada-fresh-beginnings"], []])
        game.setGigs([(6, 1), (6, 3)], for: 0)
        game.callLegend(0, 0, free: true)
        XCTAssertEqual(game.players[0].hand.count, 1)
        var twoMins = Fixtures.game(legends: [["lucyna-kushinada-fresh-beginnings"], []])
        twoMins.setGigs([(6, 1), (4, 1)], for: 0)
        twoMins.callLegend(0, 0, free: true)
        XCTAssertEqual(twoMins.players[0].hand.count, 2)
    }

    func testMistyKeepsTheTopCardWhenTheTypeMatches() {
        var game = Fixtures.game(decks: [Array(repeating: "trust-no-one", count: 6), []])
        let misty = game.place("misty-olszewski-mender-of-broken-spirits", for: 0)
        game.players[0].eddiesReady = 0
        game.players[0].eddiesSpent = 2
        game.endTurn(0)
        XCTAssertEqual(game.players[0].hand, [id("trust-no-one")])
        XCTAssertEqual(game.players[0].eddiesReady, 1)
        XCTAssertFalse(game.canAttackAtAll(0, game.unit(0, misty)!))
    }

    func testMistyTrashesTheTopCardWhenTheTypeMisses() {
        var game = Fixtures.game()
        game.place("misty-olszewski-mender-of-broken-spirits", for: 0)
        game.players[0].eddiesSpent = 2
        game.players[0].eddiesReady = 0
        game.players[0].deck = [id("trust-no-one"), id("trust-no-one"), id("corpo-security")]
        game.endTurn(0)
        XCTAssertTrue(game.players[0].hand.isEmpty)
        XCTAssertEqual(game.players[0].trash, [id("corpo-security")])
        XCTAssertEqual(game.players[0].eddiesReady, 0)
    }

    func testModdedMuramasaReadiesWhenBehindOnStreetCred() {
        var game = Fixtures.game()
        let muramasa = game.place("modded-muramasa", for: 0)
        game.setGigs([(6, 3)], for: 1)
        game.spendUnit(0, uid: muramasa)
        game.endTurn(0)
        XCTAssertEqual(game.unit(0, muramasa)?.spent, false)
    }

    func testModdedMuramasaStaysSpentWhenNotBehind() {
        var game = Fixtures.game()
        let muramasa = game.place("modded-muramasa", for: 0)
        game.setGigs([(6, 3)], for: 0)
        game.spendUnit(0, uid: muramasa)
        game.endTurn(0)
        XCTAssertEqual(game.unit(0, muramasa)?.spent, true)
    }

    func testMoxIncitersForcesARivalUnitToAttack() {
        var game = Fixtures.game()
        let rival = game.place("swordwise-huscle", for: 1)
        playFromHand(&game, "mox-inciters")
        XCTAssertEqual(game.unit(1, rival)?.mustAttackOnTurn, game.turn + 1)
    }

    func testRebootOpticsPreventsDefeatOfTheFriendlyUnitOnce() {
        var game = Fixtures.game()
        let attacker = game.place("minotaur", for: 0)
        let defender = game.place("swordwise-huscle", for: 1)
        game.spendUnit(1, uid: defender)
        game.give(["reboot-optics"], to: 1)
        game.players[1].eddiesReady = 2
        game.performAttack(0, attackerUid: attacker, target: .unit(defender))
        XCTAssertNotNil(game.unit(1, defender))
        XCTAssertNotNil(game.unit(0, attacker))
        XCTAssertTrue(game.players[1].trash.contains(id("reboot-optics")))
        XCTAssertTrue(game.players[1].flags.delayedTriggers.isEmpty)
    }

    func testRebootOpticsIsConsumedByTheFirstFightOnly() {
        var game = Fixtures.game()
        let first = game.place("minotaur", for: 0)
        let second = game.place("minotaur", for: 0)
        let defender = game.place("swordwise-huscle", for: 1)
        let other = game.place("swordwise-huscle", for: 1)
        game.spendUnit(1, uid: defender)
        game.spendUnit(1, uid: other)
        game.withContext(id("reboot-optics"), owner: 1, at: .resolving) { context in
            context.registerDelayed([.wouldBeDefeated, .wonFight], expiry: .endOfTurn)
        }
        game.performAttack(0, attackerUid: first, target: .unit(defender))
        game.performAttack(0, attackerUid: second, target: .unit(other))
        XCTAssertNotNil(game.unit(1, defender))
        XCTAssertNil(game.unit(1, other))
    }

    func testRitaWheelerLootsTheFirstTimeSpentEachTurn() {
        var game = Fixtures.game()
        let rita = game.place("rita-wheeler-no-stupid-questions", for: 0)
        game.spendUnit(0, uid: rita)
        XCTAssertEqual(game.players[0].trash.count, 1)
        XCTAssertEqual(game.players[0].deck.count, 9)
        game.readyUnit(0, uid: rita)
        game.spendUnit(0, uid: rita)
        XCTAssertEqual(game.players[0].trash.count, 1)
    }

    func testRogueAmendiaresReadiesTwoEddiesOncePerTurn() {
        var game = Fixtures.game()
        game.place("rogue-amendiares-queen-of-the-afterlife", for: 0)
        let thief = game.place("field-operator", for: 0)
        game.setGigs([(6, 1), (6, 1)], for: 1)
        game.players[0].eddiesReady = 0
        game.players[0].eddiesSpent = 5
        game.performAttack(0, attackerUid: thief, target: .gigs)
        XCTAssertEqual(game.players[0].eddiesReady, 2)
        let second = game.place("field-operator", for: 0)
        game.performAttack(0, attackerUid: second, target: .gigs)
        XCTAssertEqual(game.players[0].eddiesReady, 2)
    }

    func testRogueAmendiaresQuickWeakensARivalUnitInAFight() {
        var game = Fixtures.game()
        let rogue = game.place("rogue-amendiares-queen-of-the-afterlife", for: 0)
        let own = game.place("swordwise-huscle", for: 0)
        let enemy = game.place("minotaur", for: 1)
        game.players[0].eddiesReady = 2
        let subject = QuerySubject.fight(ownUid: own, otherUid: enemy)
        guard let use = game.abilityUses(0, timing: .fight, subject: subject).first else { return XCTFail("no Rogue option") }
        XCTAssertTrue(game.activate(0, use, subject: subject))
        XCTAssertEqual(game.unit(0, rogue)?.spent, true)
        XCTAssertEqual(game.power(1, game.unit(1, enemy)!, attacking: false), 5)
        XCTAssertEqual(game.players[0].eddiesReady, 0)
    }

    func testSashaRevealsTopCardAndGainsItsCostAsPower() {
        var game = Fixtures.game(decks: [["corpo-security", "field-operator"], []])
        let uid = game.takeUid()
        var sasha = FieldUnit(uid: uid, cardId: id("sasha-yakovleva-won-t-let-you-down"), isLegend: true)
        sasha.lagging = false
        game.players[0].field.append(sasha)
        game.setGigs([(6, 4)], for: 1)
        game.performAttack(0, attackerUid: uid, target: .gigs)
        XCTAssertEqual(game.players[0].hand, [id("field-operator")])
        XCTAssertEqual(game.power(0, game.unit(0, uid)!, attacking: false), 3)
        XCTAssertEqual(game.players[1].gigs.count, 0)
    }

    func testSashaMakesARivalDiscardWhenDefeated() {
        var game = Fixtures.game()
        let uid = game.takeUid()
        game.players[0].field.append(FieldUnit(uid: uid, cardId: id("sasha-yakovleva-won-t-let-you-down"), isLegend: true))
        game.give(["floor-it"], to: 1)
        game.defeat(0, uid: uid)
        XCTAssertTrue(game.players[1].hand.isEmpty)
        XCTAssertEqual(game.players[1].trash.count, 1)
    }

    func testUnlikelyBondBottomDecksAReadyAllyAndASpentRival() {
        var game = Fixtures.game()
        let ally = game.place("corpo-security", for: 0)
        let rival = game.place("minotaur", for: 1)
        game.spendUnit(1, uid: rival)
        game.players[0].eddiesReady = 4
        game.playProgram(0, id("unlikely-bond"), bottomAfter: false)
        XCTAssertNil(game.unit(0, ally))
        XCTAssertNil(game.unit(1, rival))
        XCTAssertEqual(game.players[0].deck.count, 11)
        XCTAssertEqual(game.players[1].deck.count, 11)
    }

    func testUnlikelyBondDoesNothingToTheRivalWithoutAReadyAlly() {
        var game = Fixtures.game()
        let ally = game.place("corpo-security", for: 0)
        game.spendUnit(0, uid: ally)
        let rival = game.place("minotaur", for: 1)
        game.spendUnit(1, uid: rival)
        game.playProgram(0, id("unlikely-bond"), bottomAfter: false)
        XCTAssertNotNil(game.unit(1, rival))
    }

    func testWakakoCallWeakensARivalUnitOrDraws() {
        var game = Fixtures.game(legends: [["wakako-okada-peace-and-harmony"], []])
        let rival = game.place("swordwise-huscle", for: 1)
        game.callLegend(0, 0, free: true)
        let weakened = game.unit(1, rival)!.bonusPower == -2
        XCTAssertTrue(weakened || game.players[0].hand.count == 1)
    }

    func testWakakoSpendDecreasesAGig() {
        var game = Fixtures.game(legends: [["wakako-okada-peace-and-harmony"], []])
        game.faceUp(0, slot: 0)
        game.players[0].wantsMinGigs = true
        game.setGigs([(6, 3)], for: 0)
        guard let use = game.abilityUses(0, timing: .mainAction).first else { return XCTFail("no Wakako option") }
        XCTAssertTrue(game.activate(0, use))
        XCTAssertEqual(game.players[0].gigs.map(\.value), [1])
        XCTAssertTrue(game.players[0].legends[0].spent)
    }

    func testWestbrookNetrunnerStopsRivalLegendsFromStealingLowGigs() {
        var game = Fixtures.game()
        playFromHand(&game, "westbrook-netrunner")
        let uid = game.takeUid()
        var legend = FieldUnit(uid: uid, cardId: id("adam-smasher-ender-of-legends"), isLegend: true)
        legend.lagging = false
        game.players[1].field.append(legend)
        game.setGigs([(6, 2), (20, 15)], for: 0)
        game.performAttack(1, attackerUid: uid, target: .gigs)
        XCTAssertEqual(game.players[0].gigs.map(\.value), [2])
    }

    func testWestbrookNetrunnerLeavesRivalUnitsFree() {
        var game = Fixtures.game()
        playFromHand(&game, "westbrook-netrunner")
        let thief = game.place("minotaur", for: 1)
        game.setGigs([(6, 2)], for: 0)
        game.performAttack(1, attackerUid: thief, target: .gigs)
        XCTAssertTrue(game.players[0].gigs.isEmpty)
    }

    func testDyingNightPistolDecreasesAGigOnAttack() {
        var game = Fixtures.game()
        let unit = game.place("swordwise-huscle", for: 0, gears: ["dying-night-v-s-pistol"])
        game.players[0].wantsMinGigs = true
        game.setGigs([(6, 3)], for: 0)
        game.setGigs([(6, 4)], for: 1)
        game.performAttack(0, attackerUid: unit, target: .gigs)
        XCTAssertEqual(game.players[0].gigs.map(\.value).min(), 1)
    }

    func testDyingNightPistolReadiesTwoEddiesOnlyOnV() {
        var game = Fixtures.game()
        game.place("v-roamer-of-the-badlands", for: 0, gears: ["dying-night-v-s-pistol"])
        game.players[0].eddiesReady = 0
        game.players[0].eddiesSpent = 3
        game.endTurn(0)
        XCTAssertEqual(game.players[0].eddiesReady, 2)
        var other = Fixtures.game()
        other.place("swordwise-huscle", for: 0, gears: ["dying-night-v-s-pistol"])
        other.players[0].eddiesReady = 0
        other.players[0].eddiesSpent = 3
        other.endTurn(0)
        XCTAssertEqual(other.players[0].eddiesReady, 0)
    }

    func testNetwatchNetdriverDrawsWhenTheHostIsSpent() {
        var game = Fixtures.game()
        let unit = game.place("swordwise-huscle", for: 0, gears: ["netwatch-netdriver"])
        game.spendUnit(0, uid: unit)
        XCTAssertEqual(game.players[0].hand.count, 1)
    }

    func testTetratronicRipplerTrashesAWeakTopCard() {
        var game = Fixtures.game(decks: [["corpo-security", "floor-it"], []])
        let unit = game.place("swordwise-huscle", for: 0, gears: ["tetratronic-rippler"])
        game.spendUnit(0, uid: unit)
        XCTAssertEqual(game.players[0].trash, [id("floor-it")])
        XCTAssertEqual(game.players[0].deck, [id("corpo-security")])
    }

    func testTetratronicRipplerKeepsAStrongTopCard() {
        var game = Fixtures.game(decks: [["floor-it", "minotaur"], []])
        let unit = game.place("swordwise-huscle", for: 0, gears: ["tetratronic-rippler"])
        game.spendUnit(0, uid: unit)
        XCTAssertTrue(game.players[0].trash.isEmpty)
        XCTAssertEqual(game.players[0].deck.last, id("minotaur"))
    }
}
