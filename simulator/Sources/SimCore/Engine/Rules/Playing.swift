extension Game {
    func effectiveCost(_ p: Int, _ id: Int) -> Int {
        let stat = stats(id)
        var cost = stat.costValue
        if profile(id).scopes.contains(.ownPlayCost) {
            let own = implementation(id).modifiers(in: query(id, owner: p, at: .hand, subject: .card(id)))
            if let override = own.costOverride { cost = override }
            if own.costReduction > 0 { cost = max(own.costMinimum, cost - own.costReduction) }
        }
        for discount in players[p].flags.pendingDiscounts where discount.amount > 0 && (discount.kind == nil || discount.kind == stat.kind) {
            cost = max(discount.minimum, cost - discount.amount)
        }
        if scopesInPlay.contains(.alliedPlayCost) {
            for reduction in alliedCostReductions(p, id) {
                cost = max(reduction.costMinimum, cost - reduction.costReduction)
            }
        }
        return cost
    }

    func alliedCostReductions(_ p: Int, _ id: Int) -> [CardModifiers] {
        var found: [CardModifiers] = []
        forEachCardInPlay(of: p, with: .alliedPlayCost) { source, location in
            let reduction = implementation(source).modifiers(in: query(source, owner: p, at: location, subject: .card(id)))
            guard reduction.costReduction > 0 else { return }
            if let key = reduction.costOncePerTurnKey, wasUsedThisTurn(p, key: key) { return }
            found.append(reduction)
        }
        return found
    }

    mutating func consumeCostReductions(_ p: Int, _ id: Int) {
        guard scopesInPlay.contains(.alliedPlayCost) else { return }
        for reduction in alliedCostReductions(p, id) {
            if let key = reduction.costOncePerTurnKey { markUsedThisTurn(p, key: key) }
        }
    }

    @discardableResult
    mutating func playFromHand(_ p: Int, handIndex: Int, equipTo: EquipTarget? = nil, free: Bool = false) -> Bool {
        guard players[p].hand.indices.contains(handIndex) else { return false }
        let id = players[p].hand[handIndex]
        let kind = stats(id).kind
        let cost = free ? 0 : effectiveCost(p, id)
        guard cost <= availableMana(p) else { return false }
        if kind == .gear {
            guard let target = equipTo ?? equipTarget(p, gear: id) else { return false }
            guard pay(p, cost) else { return false }
            removeFromHand(p, at: handIndex)
            consumeCostReductions(p, id)
            if !free { consumePendingDiscounts(p, for: .gear) }
            equip(p, gear: id, to: target)
            note("P\(p) equips \(name(id))")
            let event = GameEvent.played(cardId: id, location: .gear(host: target))
            broadcast(event, to: p)
            send(event, to: id, owner: p, at: .gear(host: target), relation: .itself)
            return true
        }
        guard pay(p, cost) else { return false }
        removeFromHand(p, at: handIndex)
        consumeCostReductions(p, id)
        switch kind {
        case .unit:
            if !free { consumePendingDiscounts(p, for: .unit) }
            enterField(p, cardId: id)
        case .program:
            playProgram(p, id, bottomAfter: false)
        default:
            break
        }
        return true
    }

    @discardableResult
    mutating func enterField(_ p: Int, cardId id: Int) -> Int {
        let uid = takeUid()
        players[p].field.append(FieldUnit(uid: uid, cardId: id, isLegend: false))
        note("P\(p) plays \(name(id))")
        broadcast(.played(cardId: id, location: .field(uid: uid)), to: p, subject: .field(uid: uid))
        return uid
    }

    mutating func playProgram(_ p: Int, _ id: Int, bottomAfter: Bool) {
        players[p].flags.programsPlayed += 1
        consumePendingDiscounts(p, for: .program)
        note("P\(p) plays \(name(id))")
        broadcast(.played(cardId: id, location: .resolving), to: p)
        send(.programResolves, to: id, owner: p, at: .resolving, relation: .itself)
        if bottomAfter { bottomDeck(p, [id]) } else { players[p].trash.append(id) }
        checkOvertimeWin()
    }

    mutating func playQuickFromHand(_ p: Int, cardId id: Int) -> Bool {
        guard let handIndex = players[p].hand.firstIndex(of: id) else { return false }
        let cost = effectiveCost(p, id)
        guard pay(p, cost) else { return false }
        removeFromHand(p, at: handIndex)
        players[p].trash.append(id)
        consumePendingDiscounts(p, for: .program)
        players[p].flags.programsPlayed += 1
        note("P\(p) plays \(name(id))")
        broadcast(.quickActivated(cardId: id), to: p)
        return true
    }

    mutating func callLegend(_ p: Int, _ slot: Int, free: Bool) {
        if !free {
            guard availableMana(p) >= 1, pay(p, 1) else { return }
        }
        players[p].flags.called = true
        players[p].legends[slot].faceUp = true
        let id = players[p].legends[slot].cardId
        note("P\(p) calls \(name(id))")
        let event = GameEvent.calledAsLegend(slot: slot)
        send(event, to: id, owner: p, at: .legend(slot: slot), relation: .itself)
        broadcast(event, to: p, subject: .legend(slot: slot), includeSubject: false)
    }

    func goSoloCost(_ p: Int, slot: Int) -> Int? {
        let id = players[p].legends[slot].cardId
        guard var cost = stats(id).cost else { return nil }
        for discount in players[p].flags.pendingDiscounts where discount.amount > 0 && discount.kind == .legend {
            cost = max(discount.minimum, cost - discount.amount)
        }
        if scopesInPlay.contains(.goSoloCost) {
            for side in 0..<2 {
                forEachCardInPlay(of: side, with: .goSoloCost) { source, location in
                    cost += implementation(source).modifiers(in: query(source, owner: side, at: location, subject: .legend(owner: p, slot: slot))).goSoloCostChange
                }
            }
        }
        return max(0, cost)
    }

    mutating func goSolo(_ p: Int, slot: Int) {
        guard players[p].legends.indices.contains(slot) else { return }
        let legend = players[p].legends[slot]
        guard let cost = goSoloCost(p, slot: slot) else { return }
        players[p].legends[slot].spent = true
        guard pay(p, cost) else {
            players[p].legends[slot].spent = legend.spent
            return
        }
        consumePendingDiscounts(p, for: .legend)
        players[p].legends.remove(at: slot)
        let uid = takeUid()
        var fieldUnit = FieldUnit(uid: uid, cardId: legend.cardId, isLegend: true)
        fieldUnit.gears = legend.gears
        fieldUnit.lagging = false
        players[p].field.append(fieldUnit)
        note("P\(p) goes solo with \(name(legend.cardId))")
        broadcast(.played(cardId: legend.cardId, location: .field(uid: uid)), to: p, subject: .field(uid: uid))
    }

    mutating func consumePendingDiscounts(_ p: Int, for kind: CardKind) {
        guard !players[p].flags.pendingDiscounts.isEmpty else { return }
        players[p].flags.pendingDiscounts.removeAll { $0.kind == kind || ($0.kind == nil && kind != .legend) }
    }

    mutating func addPendingDiscount(_ p: Int, source: Int, kind: CardKind?, amount: Int, minimum: Int) {
        players[p].flags.pendingDiscounts.removeAll { $0.sourceCardId == source }
        players[p].flags.pendingDiscounts.append(PendingDiscount(sourceCardId: source, kind: kind, amount: amount, minimum: minimum))
    }
}
