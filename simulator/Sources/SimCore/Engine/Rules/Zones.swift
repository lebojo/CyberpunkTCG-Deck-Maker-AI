extension Game {
    mutating func draw(_ p: Int, _ count: Int) {
        for _ in 0..<max(0, count) {
            guard let top = players[p].deck.popLast() else {
                if !isOver { outcome = .win(player: 1 - p, reason: .deckOut) }
                return
            }
            players[p].hand.append(top)
        }
    }

    mutating func takeTop(_ p: Int, _ count: Int) -> [Int] {
        var taken: [Int] = []
        for _ in 0..<count {
            guard let top = players[p].deck.popLast() else { break }
            taken.append(top)
        }
        return taken
    }

    mutating func bottomDeck(_ p: Int, _ ids: [Int]) {
        var shuffled = ids
        shuffled.shuffle(using: &rng)
        players[p].deck.insert(contentsOf: shuffled, at: 0)
    }

    mutating func addToHand(_ p: Int, _ id: Int, revealed: Bool = true) {
        players[p].hand.append(id)
        if revealed { players[p].revealed.append(id) }
    }

    func knownHandCards(of p: Int) -> [Int] {
        var remaining = players[p].hand
        var known: [Int] = []
        for id in players[p].revealed {
            if let position = remaining.firstIndex(of: id) {
                remaining.remove(at: position)
                known.append(id)
            }
        }
        return known
    }

    mutating func discardWorst(_ p: Int) {
        guard let index = players[p].hand.indices.min(by: { keepValue(p, players[p].hand[$0]) < keepValue(p, players[p].hand[$1]) }) else { return }
        players[p].trash.append(players[p].hand.remove(at: index))
    }

    mutating func sellTopOfDeck(_ p: Int) {
        guard let id = players[p].deck.popLast() else { return }
        if stats(id).isSellable && stats(id).kind != .legend {
            players[p].eddiesReady += 1
            players[p].trash.append(id)
        } else {
            players[p].deck.append(id)
        }
    }

    mutating func equip(_ p: Int, gear: Int, to target: EquipTarget) {
        switch target {
        case .unit(let uid):
            if let index = unitIndex(p, uid) { players[p].field[index].gears.append(gear) }
        case .legend(let slot):
            if players[p].legends.indices.contains(slot) { players[p].legends[slot].gears.append(gear) }
        }
    }

    func gears(_ p: Int, on host: EquipTarget) -> [Int] {
        switch host {
        case .unit(let uid): return unit(p, uid)?.gears ?? []
        case .legend(let slot): return players[p].legends.indices.contains(slot) ? players[p].legends[slot].gears : []
        }
    }

    @discardableResult
    mutating func removeGear(_ owner: Int, _ gear: Int, from host: EquipTarget, toTrash: Bool = true) -> Bool {
        switch host {
        case .unit(let uid):
            guard let index = unitIndex(owner, uid), let position = players[owner].field[index].gears.firstIndex(of: gear) else { return false }
            players[owner].field[index].gears.remove(at: position)
        case .legend(let slot):
            guard players[owner].legends.indices.contains(slot), let position = players[owner].legends[slot].gears.firstIndex(of: gear) else { return false }
            players[owner].legends[slot].gears.remove(at: position)
        }
        if toTrash { players[owner].trash.append(gear) }
        return true
    }

    mutating func defeat(_ owner: Int, uid: Int, cause: DefeatCause = .effect) {
        guard unitIndex(owner, uid) != nil else { return }
        if listenersInPlay.contains(.wouldBeDefeated) || !players[owner].flags.delayedTriggers.isEmpty {
            let replaced = announce(.wouldBeDefeated(uid: uid, cause: cause), aboutUnit: uid, owner: owner, stopWhenPrevented: true)
            if replaced.prevented { return }
        }
        guard let index = unitIndex(owner, uid) else { return }
        let removed = players[owner].field.remove(at: index)
        players[owner].trash.append(contentsOf: removed.gears)
        if !removed.isLegend { players[owner].trash.append(removed.cardId) }
        note("P\(owner) loses \(name(removed.cardId))")
        let report = DefeatedUnit(uid: removed.uid, cardId: removed.cardId, gears: removed.gears, wasLegend: removed.isLegend)
        let event = GameEvent.defeated(report)
        broadcast(event, to: owner)
        sendToGears(event, owner: owner, gears: removed.gears, host: nil)
        send(event, to: removed.cardId, owner: owner, at: removed.isLegend ? .removed : .trash, relation: .itself)
    }

    mutating func bottomDeckUnit(_ owner: Int, uid: Int) {
        guard let index = unitIndex(owner, uid) else { return }
        let removed = players[owner].field.remove(at: index)
        var moved = removed.gears
        if !removed.isLegend { moved.append(removed.cardId) }
        bottomDeck(owner, moved)
        note("P\(owner) has \(name(removed.cardId)) bottom-decked")
    }

    mutating func returnUnitToHand(_ owner: Int, uid: Int) {
        guard let index = unitIndex(owner, uid) else { return }
        let removed = players[owner].field.remove(at: index)
        if !removed.isLegend { players[owner].hand.append(removed.cardId) }
        players[owner].hand.append(contentsOf: removed.gears)
    }

    mutating func spendUnit(_ owner: Int, uid: Int) {
        guard let index = unitIndex(owner, uid), !players[owner].field[index].spent else { return }
        players[owner].field[index].spent = true
        announceSpent(owner, location: .field(uid: uid), gears: players[owner].field[index].gears, host: .unit(uid))
    }

    mutating func spendLegend(_ p: Int, _ slot: Int) {
        players[p].legends[slot].spent = true
        announceSpent(p, location: .legend(slot: slot), gears: players[p].legends[slot].gears, host: .legend(slot))
    }

    mutating func announceSpent(_ p: Int, location: CardLocation, gears: [Int], host: EquipTarget) {
        guard listenersInPlay.contains(.becameSpent) || !players[p].flags.delayedTriggers.isEmpty else { return }
        let event = GameEvent.becameSpent(location, isEquipped: !gears.isEmpty)
        broadcast(event, to: p, subject: location)
        sendToGears(event, owner: p, gears: gears, host: host)
    }

    mutating func readyUnit(_ owner: Int, uid: Int) {
        guard let index = unitIndex(owner, uid) else { return }
        players[owner].field[index].spent = false
    }
}
