import XCTest
@testable import SimCore

final class GreenCardsTests: XCTestCase {
    private func id(_ key: String) -> Int { Fixtures.id(key) }

    private func play(_ game: inout Game, _ key: String, for p: Int = 0, mana: Int = 10) {
        game.give([key], to: p)
        game.players[p].eddiesReady = mana
        XCTAssertTrue(game.playFromHand(p, handIndex: game.players[p].hand.count - 1))
    }

    func testDontFearTheReaperSpendsEveryRivalUnitThenDefeatsOne() {
        var game = Fixtures.game()
        let strong = game.place("minotaur", for: 1)
        let weak = game.place("corpo-security", for: 1)
        play(&game, "don-t-fear-the-reaper")
        XCTAssertNil(game.unit(1, strong))
        XCTAssertEqual(game.unit(1, weak)?.spent, true)
    }

    func testFoolOnTheHillLetsTheRivalChooseAndDrawsTwoWhenTrashed() {
        var game = Fixtures.game()
        play(&game, "fool-on-the-hill")
        XCTAssertEqual(game.players[0].hand.count, 2)
        XCTAssertTrue([1, 3].contains(game.players[0].trash.count))
    }

    func testGoroVengefulBodyguardLootsWhenAFriendlyUnitBlocks() {
        var game = Fixtures.game(legends: [["goro-takemura-vengeful-bodyguard"], []])
        game.faceUp(0, slot: 0)
        let blocker = game.place("corpo-security", for: 0)
        game.give(["psycho-squad"], to: 0)
        game.players[0].hand = [id("floor-it")]
        game.broadcast(.blocked(blockerUid: blocker, attackerUid: 99), to: 0, subject: .field(uid: blocker))
        XCTAssertEqual(game.players[0].hand.count, 1)
        XCTAssertEqual(game.players[0].trash, [id("floor-it")])
    }

    func testGoroVengefulBodyguardPumpsAFightingUnitWithAValuePair() {
        var game = Fixtures.game(legends: [["goro-takemura-vengeful-bodyguard"], []])
        game.faceUp(0, slot: 0)
        game.setGigs([(6, 3), (6, 3)], for: 0)
        game.players[0].eddiesReady = 1
        let own = game.place("swordwise-huscle", for: 0)
        let other = game.place("la-llorona-ghost-of-the-past", for: 1)
        let subject = QuerySubject.fight(ownUid: own, otherUid: other)
        guard let use = game.abilityUses(0, timing: .fight, subject: subject).first else { return XCTFail("no option") }
        XCTAssertTrue(game.activate(0, use, subject: subject))
        XCTAssertEqual(game.power(0, game.unit(0, own)!, attacking: false), 4)
        XCTAssertTrue(game.players[0].legends[0].spent)
    }

    func testJackieDoesNotPayWhenSheIsTheUnitBeingDefeated() {
        var game = Fixtures.game()
        var jackie = FieldUnit(uid: game.takeUid(), cardId: id("jackie-welles-mama-s-favorite"), isLegend: true)
        jackie.lagging = false
        game.players[0].field.append(jackie)
        game.players[0].eddiesReady = 1
        game.defeat(0, uid: jackie.uid)
        XCTAssertNil(game.unit(0, jackie.uid))
        XCTAssertEqual(game.players[0].eddiesReady, 1)
    }

    func testJackieSacrificesHerselfToSaveAFriendlyUnit() {
        var game = Fixtures.game()
        var jackie = FieldUnit(uid: game.takeUid(), cardId: id("jackie-welles-mama-s-favorite"), isLegend: true)
        jackie.lagging = false
        game.players[0].field.append(jackie)
        let saved = game.place("minotaur", for: 0)
        game.players[0].eddiesReady = 1
        game.defeat(0, uid: saved)
        XCTAssertNotNil(game.unit(0, saved))
        XCTAssertNil(game.unit(0, jackie.uid))
        XCTAssertEqual(game.players[0].eddiesReady, 0)
    }

    func testMaelstromZealotsDefeatTheOpposingUnitWhenTheyLose() {
        var game = Fixtures.game()
        let zealots = game.place("maelstrom-zealots", for: 1)
        game.spendUnit(1, uid: zealots)
        let attacker = game.place("swordwise-huscle", for: 0)
        game.performAttack(0, attackerUid: attacker, target: .unit(zealots))
        XCTAssertNil(game.unit(0, attacker))
        XCTAssertNil(game.unit(1, zealots))
    }

    func testMaxTacHeavyCostsLessPerRivalUnitWithMinimumOne() {
        var game = Fixtures.game()
        let heavy = id("maxtac-heavy")
        XCTAssertEqual(game.effectiveCost(0, heavy), 7)
        for _ in 0..<3 { game.place("corpo-security", for: 1) }
        XCTAssertEqual(game.effectiveCost(0, heavy), 4)
        for _ in 0..<6 { game.place("corpo-security", for: 1) }
        XCTAssertEqual(game.effectiveCost(0, heavy), 1)
    }

    func testMaxTacSquadronReadiesALegendAtEndOfTurnOnlyWhenSpent() {
        var game = Fixtures.game(legends: [["hanako-arasaka-daughter-of-the-emperor"], []])
        game.faceUp(0, slot: 0)
        let squadron = game.place("maxtac-squadron", for: 0)
        game.spendLegend(0, 0)
        game.endTurn(0)
        XCTAssertTrue(game.players[0].legends[0].spent)
        game.active = 0
        game.spendUnit(0, uid: squadron)
        game.endTurn(0)
        XCTAssertFalse(game.players[0].legends[0].spent)
    }

    func testMemoryRelapseSpendsLocksAndDrawsOnEvenStreetCred() {
        var game = Fixtures.game()
        game.setGigs([(4, 2)], for: 0)
        let target = game.place("swordwise-huscle", for: 1)
        play(&game, "memory-relapse")
        XCTAssertEqual(game.unit(1, target)?.spent, true)
        XCTAssertGreaterThan(game.unit(1, target)!.cannotReadyBefore, game.turn)
        XCTAssertEqual(game.players[0].hand.count, 1)
    }

    func testMemoryRelapseDoesNotDrawOnOddStreetCred() {
        var game = Fixtures.game()
        game.setGigs([(4, 3)], for: 0)
        game.place("swordwise-huscle", for: 1)
        play(&game, "memory-relapse")
        XCTAssertTrue(game.players[0].hand.isEmpty)
    }

    func testNadiaAttacksGigsTheTurnSheIsPlayedOnlyWhenBehindOnGigs() {
        var game = Fixtures.game()
        game.setGigs([(4, 1)], for: 1)
        let nadia = game.place("nadia-fighting-through-grief", for: 0, ready: false)
        XCTAssertTrue(game.canAttackAtAll(0, game.unit(0, nadia)!))
        game.setGigs([(4, 1)], for: 0)
        XCTAssertFalse(game.canAttackAtAll(0, game.unit(0, nadia)!))
    }

    func testOverwatchDiscardsToDefeatASpentRivalUnitOfEqualOrLowerCost() {
        var game = Fixtures.game()
        game.place("swordwise-huscle", for: 0, gears: ["overwatch-panam-s-gift"])
        let target = game.place("swordwise-huscle", for: 1)
        game.spendUnit(1, uid: target)
        game.players[0].hand = [id("minotaur"), id("psycho-squad")]
        game.players[0].eddiesReady = 1
        guard let use = game.abilityUses(0, timing: .mainAction).first else { return XCTFail("no option") }
        XCTAssertTrue(game.activate(0, use))
        XCTAssertNil(game.unit(1, target))
        XCTAssertEqual(game.players[0].hand.count, 1)
        XCTAssertEqual(game.players[0].trash.count, 1)
        XCTAssertTrue(game.players[0].field[0].spent)
    }

    func testOverwatchNeedsADiscardAtLeastAsExpensiveAsTheTarget() {
        var game = Fixtures.game()
        game.place("swordwise-huscle", for: 0, gears: ["overwatch-panam-s-gift"])
        let target = game.place("minotaur", for: 1)
        game.spendUnit(1, uid: target)
        game.players[0].hand = [id("floor-it")]
        game.players[0].eddiesReady = 1
        XCTAssertTrue(game.abilityUses(0, timing: .mainAction).isEmpty)
    }

    func testPacificaLocksARivalUnitOnEvenStreetCred() {
        var game = Fixtures.game()
        game.setGigs([(4, 2)], for: 0)
        let target = game.place("swordwise-huscle", for: 1)
        game.spendUnit(1, uid: target)
        play(&game, "pacifica-netrunner")
        XCTAssertGreaterThan(game.unit(1, target)!.cannotReadyBefore, game.turn)
    }

    func testPacificaDoesNothingOnOddStreetCred() {
        var game = Fixtures.game()
        game.setGigs([(4, 3)], for: 0)
        let target = game.place("swordwise-huscle", for: 1)
        game.spendUnit(1, uid: target)
        play(&game, "pacifica-netrunner")
        XCTAssertEqual(game.unit(1, target)!.cannotReadyBefore, 0)
    }

    func testPadreCallChoosesAnEffect() {
        var game = Fixtures.game(legends: [["padre-man-of-the-cross"], []])
        let target = game.place("swordwise-huscle", for: 1)
        game.callLegend(0, 0, free: true)
        XCTAssertTrue(game.unit(1, target)?.spent == true || game.players[0].hand.count == 1)
    }

    func testPadreSpendSetsAGigToMatchAnother() {
        var game = Fixtures.game(legends: [["padre-man-of-the-cross"], []])
        game.faceUp(0, slot: 0)
        game.setGigs([(10, 7), (10, 4)], for: 0)
        game.setGigs([(10, 7)], for: 1)
        guard let use = game.abilityUses(0, timing: .beforeAttacks).first else { return XCTFail("no option") }
        XCTAssertTrue(game.activate(0, use))
        XCTAssertEqual(game.valuePairs(0), 1)
        XCTAssertTrue(game.players[0].legends[0].spent)
    }

    func testPadreBreaksARivalPairWhenItHelpsMoreThanMatchingOwnGigs() {
        var game = Fixtures.game(legends: [["padre-man-of-the-cross"], []])
        game.faceUp(0, slot: 0)
        game.setGigs([(10, 3)], for: 0)
        game.setGigs([(10, 7), (10, 7)], for: 1)
        guard let use = game.abilityUses(0, timing: .beforeAttacks).first else { return XCTFail("no option") }
        XCTAssertTrue(game.activate(0, use))
        XCTAssertEqual(game.players[0].gigs.map(\.value), [3])
        XCTAssertEqual(game.valuePairs(1), 0)
        XCTAssertTrue(game.players[1].gigs.contains { $0.value == 3 })
    }

    func testPanamNomadCavalryMovesAGearAndReadiesTheUnit() {
        var game = Fixtures.game(legends: [["panam-palmer-nomad-cavalry"], []])
        game.faceUp(0, slot: 0)
        game.players[0].legends[0].gears = [id("mantis-blades")]
        let unit = game.place("swordwise-huscle", for: 0)
        game.spendUnit(0, uid: unit)
        game.players[0].eddiesReady = 2
        guard let use = game.abilityUses(0, timing: .mainAction).first else { return XCTFail("no option") }
        XCTAssertTrue(game.activate(0, use))
        XCTAssertEqual(game.unit(0, unit)?.gears, [id("mantis-blades")])
        XCTAssertEqual(game.unit(0, unit)?.spent, false)
        XCTAssertTrue(game.players[0].legends[0].gears.isEmpty)
        XCTAssertTrue(game.players[0].legends[0].spent)
    }

    func testPanamNomadCavalryReadiesEquippedUnitsWithFiveEquipped() {
        var game = Fixtures.game(legends: [["panam-palmer-nomad-cavalry"], []])
        game.faceUp(0, slot: 0)
        game.players[0].legends[0].gears = [id("mantis-blades")]
        var uids: [Int] = []
        for _ in 0..<4 { uids.append(game.place("corpo-security", for: 0, gears: ["mantis-blades"])) }
        let plain = game.place("corpo-security", for: 0)
        for uid in uids + [plain] { game.spendUnit(0, uid: uid) }
        game.spendLegend(0, 0)
        game.endTurn(0)
        XCTAssertTrue(uids.allSatisfy { game.unit(0, $0)?.spent == false })
        XCTAssertEqual(game.unit(0, plain)?.spent, true)
        XCTAssertFalse(game.players[0].legends[0].spent)
    }

    func testPanamNomadCavalryDoesNotReadyWithFourEquipped() {
        var game = Fixtures.game(legends: [["panam-palmer-nomad-cavalry"], []])
        game.faceUp(0, slot: 0)
        let uid = game.place("corpo-security", for: 0, gears: ["mantis-blades"])
        game.spendUnit(0, uid: uid)
        game.endTurn(0)
        XCTAssertEqual(game.unit(0, uid)?.spent, true)
    }

    func testPanamStrengthThroughFamilyCallsALegendForFreeAtTurnStart() {
        var game = Fixtures.game(legends: [["padre-man-of-the-cross"], []])
        game.place("panam-palmer-strength-through-family", for: 0)
        game.broadcast(.turnStarted, to: 0)
        XCTAssertTrue(game.players[0].legends[0].faceUp)
        XCTAssertTrue(game.players[0].flags.called)
    }

    func testPanamStrengthThroughFamilyAttackDiscardsThenDrawsPerFaceUpLegend() {
        var game = Fixtures.game(legends: [["padre-man-of-the-cross", "hanako-arasaka-daughter-of-the-emperor"], []])
        game.faceUp(0, slot: 0)
        game.faceUp(0, slot: 1)
        let panam = game.place("panam-palmer-strength-through-family", for: 0)
        game.players[0].hand = [id("corpo-security")]
        game.setGigs([(4, 1)], for: 1)
        game.performAttack(0, attackerUid: panam, target: .gigs)
        XCTAssertEqual(game.players[0].hand.count, 2)
        XCTAssertTrue(game.players[0].trash.contains(id("corpo-security")))
    }

    func testRiotShieldGivesBlockerAndTaxesRivalGoSolo() {
        var game = Fixtures.game(legends: [["jackie-welles-mama-s-favorite"], ["jackie-welles-mama-s-favorite"]])
        let host = game.place("swordwise-huscle", for: 1, gears: ["riot-shield"])
        XCTAssertEqual(game.goSoloCost(0, slot: 0), 8)
        XCTAssertEqual(game.goSoloCost(1, slot: 0), 6)
        XCTAssertTrue(game.isBlocker(1, game.unit(1, host)!))
    }

    func testTygersWhisperCallsALegendForFreeOnce() {
        var game = Fixtures.game(legends: [["padre-man-of-the-cross", "hanako-arasaka-daughter-of-the-emperor"], []])
        play(&game, "tyger-s-whisper", mana: 2)
        XCTAssertEqual(game.players[0].legends.filter(\.faceUp).count, 1)
        play(&game, "tyger-s-whisper", mana: 2)
        XCTAssertEqual(game.players[0].legends.filter(\.faceUp).count, 1)
    }

    func testValentinoGivesAdrenalineToAnotherUnitPlayedThisTurn() {
        var game = Fixtures.game()
        let ally = game.place("psycho-squad", for: 0, ready: false)
        XCTAssertFalse(game.canAttackAtAll(0, game.unit(0, ally)!))
        play(&game, "valentino-street-racer")
        XCTAssertTrue(game.canAttackAtAll(0, game.unit(0, ally)!))
        let racer = game.players[0].field.last!
        XCTAssertFalse(game.canAttackAtAll(0, racer))
    }

    func testValentinoIgnoresUnitsCostingMoreThanFive() {
        var game = Fixtures.game()
        let big = game.place("minotaur", for: 0, ready: false)
        play(&game, "valentino-street-racer")
        XCTAssertFalse(game.canAttackAtAll(0, game.unit(0, big)!))
    }

    func testWeGottaLiveTogetherCostsThreeWhenTwoGigsBehind() {
        var game = Fixtures.game()
        let program = id("we-gotta-live-together")
        XCTAssertEqual(game.effectiveCost(0, program), 5)
        game.setGigs([(4, 1), (4, 2)], for: 1)
        XCTAssertEqual(game.effectiveCost(0, program), 3)
        game.setGigs([(4, 1)], for: 0)
        XCTAssertEqual(game.effectiveCost(0, program), 5)
    }

    func testWeGottaLiveTogetherPlaysUpToTwoCheapUnitsFromTrash() {
        var game = Fixtures.game()
        game.players[0].trash = [id("corpo-security"), id("minotaur"), id("swordwise-huscle"), id("field-operator")]
        play(&game, "we-gotta-live-together")
        XCTAssertEqual(game.players[0].field.count, 2)
        XCTAssertTrue(game.players[0].trash.contains(id("minotaur")))
        XCTAssertEqual(game.players[0].trash.count, 3)
    }

    func testWraithMaraudersReadyASpentUnitWithPowerEqualToTheStolenGig() {
        var game = Fixtures.game()
        let wraith = game.place("wraith-marauders", for: 0)
        let ally = game.place("swordwise-huscle", for: 0)
        let wrong = game.place("psycho-squad", for: 0)
        game.spendUnit(0, uid: ally)
        game.spendUnit(0, uid: wrong)
        game.setGigs([(4, 3)], for: 1)
        game.performAttack(0, attackerUid: wraith, target: .gigs)
        XCTAssertEqual(game.unit(0, ally)?.spent, false)
        XCTAssertEqual(game.unit(0, wrong)?.spent, true)
    }

    func testZetatechBerserkCostsLessPerFaceUpLegendWithMinimumOne() {
        var game = Fixtures.game(legends: [["padre-man-of-the-cross", "hanako-arasaka-daughter-of-the-emperor", "goro-takemura-vengeful-bodyguard"], []])
        let berserk = id("zetatech-berserk")
        XCTAssertEqual(game.effectiveCost(0, berserk), 6)
        game.faceUp(0, slot: 0)
        game.faceUp(0, slot: 1)
        XCTAssertEqual(game.effectiveCost(0, berserk), 4)
        game.faceUp(0, slot: 2)
        XCTAssertEqual(game.effectiveCost(0, berserk), 3)
    }

    func testHanakoSwapNotifiesTheRivalMeredithStout() {
        var game = Fixtures.game(legends: [["hanako-arasaka-daughter-of-the-emperor"], []])
        game.faceUp(0, slot: 0)
        game.setGigs([(10, 4), (10, 1)], for: 0)
        game.setGigs([(10, 4)], for: 1)
        game.place("meredith-stout-stone-cold-corpo", for: 1)
        game.players[1].trash = [id("floor-it")]
        guard let use = game.abilityUses(0, timing: .beforeAttacks).first else { return XCTFail("no option") }
        XCTAssertTrue(game.activate(0, use))
        XCTAssertEqual(game.players[0].gigs.map(\.value), [4, 4])
        XCTAssertEqual(game.players[1].hand, [id("floor-it")])
    }

    func testTakeControlDrawsWhenTheAttackerIsAVehicle() {
        var game = Fixtures.game()
        let attacker = game.place("delamain-cab", for: 0)
        game.setGigs([(4, 1)], for: 1)
        game.give(["take-control"], to: 1)
        game.players[1].eddiesReady = 2
        game.performAttack(0, attackerUid: attacker, target: .gigs)
        XCTAssertEqual(game.players[1].gigs.count, 1)
        XCTAssertEqual(game.players[1].hand.count, 1)
    }

    func testTakeControlDoesNotDrawForAnOrdinaryAttacker() {
        var game = Fixtures.game()
        let attacker = game.place("swordwise-huscle", for: 0)
        game.setGigs([(4, 1)], for: 1)
        game.give(["take-control"], to: 1)
        game.players[1].eddiesReady = 2
        game.performAttack(0, attackerUid: attacker, target: .gigs)
        XCTAssertEqual(game.players[1].gigs.count, 1)
        XCTAssertTrue(game.players[1].hand.isEmpty)
    }
}
