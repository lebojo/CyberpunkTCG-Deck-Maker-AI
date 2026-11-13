public enum PowerDuration: Sendable {
    case thisTurn
    case thisFight
    case untilYourNextTurn
}

public extension EffectContext {
    mutating func note(_ message: String) { game.note(message) }

    mutating func draw(_ count: Int, for p: Int? = nil) { game.draw(p ?? owner, count) }

    mutating func discardWorst(_ p: Int? = nil) { game.discardWorst(p ?? owner) }

    @discardableResult
    mutating func discard(_ id: Int, from p: Int? = nil) -> Bool {
        let side = p ?? owner
        guard let index = game.players[side].hand.firstIndex(of: id) else { return false }
        game.players[side].trash.append(game.removeFromHand(side, at: index))
        return true
    }

    mutating func discard(atHandIndex index: Int) {
        guard game.players[owner].hand.indices.contains(index) else { return }
        game.players[owner].trash.append(game.removeFromHand(owner, at: index))
    }

    @discardableResult
    mutating func takeFromHand(_ id: Int, of p: Int? = nil) -> Bool {
        let side = p ?? owner
        guard let index = game.players[side].hand.firstIndex(of: id) else { return false }
        game.removeFromHand(side, at: index)
        return true
    }

    mutating func takeFromTrash(at index: Int, of p: Int? = nil) -> Int? {
        let side = p ?? owner
        guard game.players[side].trash.indices.contains(index) else { return nil }
        return game.players[side].trash.remove(at: index)
    }

    @discardableResult
    mutating func takeLastFromTrash(_ id: Int, of p: Int? = nil) -> Bool {
        let side = p ?? owner
        guard let index = game.players[side].trash.lastIndex(of: id) else { return false }
        game.players[side].trash.remove(at: index)
        return true
    }

    mutating func putInTrash(_ ids: [Int], of p: Int? = nil) { game.players[p ?? owner].trash.append(contentsOf: ids) }

    mutating func trashTop(_ count: Int, of p: Int? = nil) -> [Int] {
        let side = p ?? owner
        let milled = game.takeTop(side, count)
        game.players[side].trash.append(contentsOf: milled)
        return milled
    }

    mutating func takeTop(_ count: Int, of p: Int? = nil) -> [Int] { game.takeTop(p ?? owner, count) }

    mutating func putOnTop(_ ids: [Int], of p: Int? = nil) { game.players[p ?? owner].deck.append(contentsOf: ids) }

    mutating func bottomDeck(_ ids: [Int], of p: Int? = nil) {
        guard !ids.isEmpty else { return }
        game.bottomDeck(p ?? owner, ids)
    }

    mutating func addToHand(_ id: Int, revealed: Bool = true, of p: Int? = nil) { game.addToHand(p ?? owner, id, revealed: revealed) }

    mutating func sellTopOfDeck() { game.sellTopOfDeck(owner) }

    @discardableResult
    mutating func sell(_ id: Int) -> Bool {
        guard game.stats(id).isSellable, takeFromHand(id) else { return false }
        game.players[owner].eddiesReady += 1
        return true
    }

    mutating func searchTop(_ count: Int, take limit: Int, revealed: Bool = true, where filter: (Int) -> Bool = { _ in true }, preferring better: ((Int, Int) -> Bool)? = nil) -> [Int] {
        let looked = takeTop(count)
        let ranked = better.map { looked.sorted(by: $0) } ?? looked
        var taken: [Int] = []
        var rest: [Int] = []
        for id in ranked {
            if taken.count < limit && filter(id) { taken.append(id) } else { rest.append(id) }
        }
        for id in taken { addToHand(id, revealed: revealed) }
        bottomDeck(rest)
        return taken
    }

    mutating func takeFromDeck(where filter: (Int) -> Bool) -> Int? {
        guard let index = game.players[owner].deck.lastIndex(where: filter) else { return nil }
        return game.players[owner].deck.remove(at: index)
    }

    mutating func shuffleDeck() { game.players[owner].deck.shuffle(using: &game.rng) }

    mutating func readyEddies(_ count: Int) { game.readyEddies(owner, count) }

    mutating func payEddies(_ amount: Int) -> Bool { game.pay(owner, amount) }

    @discardableResult
    mutating func playFromHand(_ id: Int, free: Bool = false, equipTo target: EquipTarget? = nil, newestCopy: Bool = false) -> Bool {
        let hand = game.players[owner].hand
        guard let index = newestCopy ? hand.lastIndex(of: id) : hand.firstIndex(of: id) else { return false }
        return game.playFromHand(owner, handIndex: index, equipTo: target, free: free)
    }

    mutating func playProgram(_ id: Int, bottomAfter: Bool) { game.playProgram(owner, id, bottomAfter: bottomAfter) }

    mutating func playQuickFromHand(_ id: Int) -> Bool { game.playQuickFromHand(owner, cardId: id) }

    @discardableResult
    mutating func putUnitIntoPlay(_ id: Int) -> Int { game.enterField(owner, cardId: id) }

    @discardableResult
    mutating func playForFree(_ id: Int, equipTo target: EquipTarget? = nil, bottomDeckProgram: Bool = false) -> Bool {
        switch game.stats(id).kind {
        case .unit:
            game.enterField(owner, cardId: id)
        case .gear:
            guard let destination = target ?? game.equipTarget(owner, gear: id) else { return false }
            game.equip(owner, gear: id, to: destination)
            game.note("P\(owner) equips \(game.name(id))")
            let event = GameEvent.played(cardId: id, location: .gear(host: destination))
            game.broadcast(event, to: owner)
            game.send(event, to: id, owner: owner, at: .gear(host: destination), relation: .itself)
        case .program:
            game.playProgram(owner, id, bottomAfter: bottomDeckProgram)
        case .legend:
            return false
        }
        return true
    }

    mutating func moveGear(_ gear: Int, from source: EquipTarget, to destination: EquipTarget) {
        guard game.removeGear(owner, gear, from: source, toTrash: false) else { return }
        game.equip(owner, gear: gear, to: destination)
    }

    mutating func removeLegendFromGame(slot: Int) {
        guard game.players[owner].legends.indices.contains(slot) else { return }
        let removed = game.players[owner].legends.remove(at: slot)
        game.players[owner].trash.append(contentsOf: removed.gears)
    }

    mutating func callLegend(slot: Int, free: Bool) { game.callLegend(owner, slot, free: free) }

    func firstFaceDownLegend(where filter: (CardData) -> Bool = { _ in true }) -> Int? {
        game.players[owner].legends.indices.first { slot in
            let legend = game.players[owner].legends[slot]
            return !legend.faceUp && filter(game.data(legend.cardId))
        }
    }

    mutating func defeat(_ p: Int, uid: Int) { game.defeat(p, uid: uid) }

    mutating func defeatAfterFight(_ p: Int, uid: Int) { outcome.defeatsAfterFight.append(UnitRef(owner: p, uid: uid)) }

    mutating func defeatGear(_ target: GearTarget) { game.removeGear(target.owner, target.gear, from: target.host) }

    mutating func bottomDeckUnit(_ p: Int, uid: Int) { game.bottomDeckUnit(p, uid: uid) }

    mutating func returnUnitToHand(_ p: Int, uid: Int) { game.returnUnitToHand(p, uid: uid) }

    mutating func spendUnit(_ p: Int, uid: Int) { game.spendUnit(p, uid: uid) }

    mutating func readyUnit(_ p: Int, uid: Int) { game.readyUnit(p, uid: uid) }

    mutating func spendLegend(slot: Int) { game.spendLegend(owner, slot) }

    mutating func readyLegend(slot: Int) {
        guard game.players[owner].legends.indices.contains(slot) else { return }
        game.players[owner].legends[slot].spent = false
    }

    mutating func spendSelf() {
        switch location {
        case .legend(let slot): game.spendLegend(owner, slot)
        case .field(let uid): game.spendUnit(owner, uid: uid)
        case .gear(.unit(let uid)): game.spendUnit(owner, uid: uid)
        case .gear(.legend(let slot)): game.spendLegend(owner, slot)
        default: break
        }
    }

    mutating func readyHost() {
        switch host {
        case .unit(let uid): game.readyUnit(owner, uid: uid)
        case .legend(let slot): readyLegend(slot: slot)
        case nil: break
        }
    }

    mutating func addPower(_ p: Int, uid: Int, _ amount: Int, _ duration: PowerDuration = .thisTurn) {
        guard let index = game.unitIndex(p, uid) else { return }
        switch duration {
        case .thisTurn: game.players[p].field[index].bonusPower += amount
        case .thisFight: game.players[p].field[index].fightBonus += amount
        case .untilYourNextTurn:
            if game.turn >= game.players[p].field[index].lingeringPowerUntil { game.players[p].field[index].lingeringPower = 0 }
            game.players[p].field[index].lingeringPower += amount
            game.players[p].field[index].lingeringPowerUntil = game.turn + 2
        }
    }

    mutating func grantKeyword(_ keyword: Keyword, to p: Int, uid: Int) {
        guard let index = game.unitIndex(p, uid) else { return }
        game.players[p].field[index].grantedKeywords.formUnion(keyword)
    }

    mutating func forbidAttackUntilYourNextTurn(_ p: Int, uid: Int) {
        guard let index = game.unitIndex(p, uid) else { return }
        game.players[p].field[index].cannotAttackBefore = game.turn + 2
    }

    mutating func forbidReadyUntilYourNextTurn(_ p: Int, uid: Int) {
        guard let index = game.unitIndex(p, uid) else { return }
        game.players[p].field[index].cannotReadyBefore = game.turn + 2
    }

    mutating func forceAttackNextTurn(_ p: Int, uid: Int) {
        guard let index = game.unitIndex(p, uid) else { return }
        game.players[p].field[index].mustAttackOnTurn = game.turn + 1
    }

    mutating func defeatAtEndOfTurn(_ p: Int, uid: Int) {
        guard let index = game.unitIndex(p, uid) else { return }
        game.players[p].field[index].defeatAtEnd = true
    }

    func unitHasMark(_ p: Int, uid: Int, key: Int) -> Bool {
        game.unit(p, uid)?.turnMarks.contains(key) ?? false
    }

    mutating func markUnit(_ p: Int, uid: Int, key: Int) {
        guard let index = game.unitIndex(p, uid), !game.players[p].field[index].turnMarks.contains(key) else { return }
        game.players[p].field[index].turnMarks.append(key)
    }

    mutating func useOncePerTurn(_ key: Int) -> Bool {
        guard !game.wasUsedThisTurn(owner, key: key) else { return false }
        game.markUsedThisTurn(owner, key: key)
        return true
    }

    @discardableResult
    mutating func adjustGigBest(by maxDelta: Int) -> Bool { game.adjustGigBest(owner, maxDelta: maxDelta) }

    @discardableResult
    mutating func increaseGigBest(by amount: Int) -> Bool { game.increaseGigBest(owner, by: amount) }

    @discardableResult
    mutating func decreaseGigBest(by amount: Int) -> Bool { game.decreaseGigBest(owner, by: amount) }

    @discardableResult
    mutating func setGigToMatchBest() -> Bool { game.setGigToMatchBest(owner) }

    mutating func setGig(_ p: Int, index: Int, to value: Int) {
        game.adjustGig(p, index: index, to: value)
        if p != owner { game.broadcast(.gigsAlteredByRival, to: p) }
    }

    mutating func swapGigs(mine: Int, theirs: Int, notifyingRival: Bool = true) {
        game.swapGigs(owner, mine: mine, theirs: theirs)
        if notifyingRival { game.broadcast(.gigsAlteredByRival, to: rival) }
    }

    mutating func stealExtraGig(attackerUid: Int, choosing pick: (Game) -> Gig?) {
        game.stealExtraGig(owner, attackerUid: attackerUid, choosing: pick)
    }

    mutating func takeRivalGig(at index: Int) {
        let gigs = game.players[rival].gigs
        guard gigs.indices.contains(index) else { return }
        game.moveGig(gigs[index], from: rival, to: owner)
        game.broadcast(.gigsAlteredByRival, to: rival)
    }

    mutating func rerollGig(_ p: Int? = nil, index: Int) {
        let side = p ?? owner
        guard game.players[side].gigs.indices.contains(index) else { return }
        let sides = game.players[side].gigs[index].sides
        game.players[side].gigs[index].value = Int.random(in: 1...sides, using: &game.rng)
    }

    mutating func reduceSteal(by amount: Int) { outcome.stealReduction += amount }

    mutating func prevent() { outcome.prevented = true }

    mutating func consumeDelayedTrigger() { outcome.consumedDelayed = true }

    mutating func registerDelayed(_ listens: EventMask, expiry: EffectExpiry, charges: Int = 1, payload: Int = 0) {
        let id = game.takeUid()
        game.players[owner].flags.delayedTriggers.append(DelayedTrigger(id: id, sourceCardId: cardId, listens: listens, expiry: expiry, charges: charges, payload: payload))
    }

    mutating func discountNext(_ kind: CardKind?, by amount: Int, minimum: Int = 1) {
        game.addPendingDiscount(owner, source: cardId, kind: kind, amount: amount, minimum: minimum)
    }

    mutating func chooseMode(_ count: Int, chooser: Int? = nil, _ apply: (Int, inout EffectContext) -> Void) -> Int {
        let decider = chooser ?? owner
        var best: (mode: Int, score: Double)?
        for mode in 0..<count {
            var trial = self
            trial.game.tracing = false
            apply(mode, &trial)
            let score = trial.game.evaluate(decider)
            if score > (best?.score ?? -Double.infinity) { best = (mode, score) }
        }
        let chosen = best?.mode ?? 0
        apply(chosen, &self)
        return chosen
    }

    mutating func chooseMode(_ options: [ModeOption], chooser: Int? = nil, _ apply: (Int, inout EffectContext) -> Void) -> Int {
        guard let chosen = ModeOption.best(options) else { return 0 }
        note("P\(chooser ?? owner) chooses \(options[chosen].name)")
        apply(chosen, &self)
        return chosen
    }
}
