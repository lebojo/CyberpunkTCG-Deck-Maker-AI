public struct UnitRef: Sendable, Hashable {
    public let owner: Int
    public let uid: Int

    public init(owner: Int, uid: Int) {
        self.owner = owner
        self.uid = uid
    }
}

struct EventOutcome: Sendable {
    var prevented = false
    var stealReduction = 0
    var defeatsAfterFight: [UnitRef] = []
    var consumedDelayed = false

    mutating func merge(_ other: EventOutcome) {
        prevented = prevented || other.prevented
        stealReduction += other.stealReduction
        if !other.defeatsAfterFight.isEmpty { defeatsAfterFight.append(contentsOf: other.defeatsAfterFight) }
    }
}

extension Game {
    @discardableResult
    mutating func send(_ event: GameEvent, to cardId: Int, owner: Int, at location: CardLocation, relation: EventRelation, delayedPayload: Int = 0, force: Bool = false) -> EventOutcome {
        guard force || catalog.profiles[cardId].listens.contains(event.mask) else { return EventOutcome() }
        let card = catalog.cards[cardId]
        return withContext(cardId, owner: owner, at: location, relation: relation, delayedPayload: delayedPayload) { context in
            card.action(event, in: &context)
            return context.outcome
        }
    }

    @discardableResult
    mutating func sendToGears(_ event: GameEvent, owner: Int, gears: [Int], host: EquipTarget?, stopWhenPrevented: Bool = false) -> EventOutcome {
        var outcome = EventOutcome()
        guard listenersInPlay.contains(event.mask) else { return outcome }
        for gear in gears {
            let location: CardLocation = host.map { .gear(host: $0) } ?? .trash
            outcome.merge(send(event, to: gear, owner: owner, at: location, relation: .attachedTo))
            if stopWhenPrevented && outcome.prevented { return outcome }
        }
        return outcome
    }

    @discardableResult
    mutating func broadcast(_ event: GameEvent, to p: Int, subject: CardLocation? = nil, includeSubject: Bool = true, relation: EventRelation = .ally, stopWhenPrevented: Bool = false) -> EventOutcome {
        var outcome = EventOutcome()
        let mask = event.mask
        if listenersInPlay.contains(mask) {
            outcome.merge(broadcastToLegends(event, to: p, subject: subject, includeSubject: includeSubject, relation: relation, stopWhenPrevented: stopWhenPrevented))
            if stopWhenPrevented && outcome.prevented { return outcome }
            outcome.merge(broadcastToField(event, to: p, subject: subject, includeSubject: includeSubject, relation: relation, stopWhenPrevented: stopWhenPrevented))
            if stopWhenPrevented && outcome.prevented { return outcome }
        }
        outcome.merge(fireDelayedTriggers(event, for: p, stopWhenPrevented: stopWhenPrevented))
        return outcome
    }

    mutating func broadcastToLegends(_ event: GameEvent, to p: Int, subject: CardLocation?, includeSubject: Bool, relation: EventRelation, stopWhenPrevented: Bool) -> EventOutcome {
        var outcome = EventOutcome()
        var slot = 0
        while slot < players[p].legends.count {
            let legend = players[p].legends[slot]
            let location = CardLocation.legend(slot: slot)
            let isSubject = location == subject
            if legend.faceUp, includeSubject || !isSubject, profile(legend.cardId).listens.contains(event.mask) {
                outcome.merge(send(event, to: legend.cardId, owner: p, at: location, relation: isSubject ? .itself : relation))
                if stopWhenPrevented && outcome.prevented { return outcome }
            }
            slot += 1
        }
        return outcome
    }

    mutating func broadcastToField(_ event: GameEvent, to p: Int, subject: CardLocation?, includeSubject: Bool, relation: EventRelation, stopWhenPrevented: Bool) -> EventOutcome {
        var outcome = EventOutcome()
        let mask = event.mask
        guard players[p].field.contains(where: { profile($0.cardId).listens.contains(mask) }) else { return outcome }
        let listeners = players[p].field.filter { profile($0.cardId).listens.contains(mask) }.map(\.uid)
        for uid in listeners {
            guard let current = unit(p, uid) else { continue }
            let location = CardLocation.field(uid: uid)
            let isSubject = location == subject
            if !includeSubject && isSubject { continue }
            outcome.merge(send(event, to: current.cardId, owner: p, at: location, relation: isSubject ? .itself : relation))
            if stopWhenPrevented && outcome.prevented { return outcome }
        }
        return outcome
    }

    mutating func fireDelayedTriggers(_ event: GameEvent, for p: Int, stopWhenPrevented: Bool) -> EventOutcome {
        var outcome = EventOutcome()
        let mask = event.mask
        guard players[p].flags.delayedTriggers.contains(where: { $0.listens.contains(mask) }) else { return outcome }
        let ids = players[p].flags.delayedTriggers.filter { $0.listens.contains(mask) }.map(\.id)
        for id in ids {
            guard let trigger = players[p].flags.delayedTriggers.first(where: { $0.id == id }) else { continue }
            let result = send(event, to: trigger.sourceCardId, owner: p, at: .delayed(id: id), relation: .delayed, delayedPayload: trigger.payload, force: true)
            if result.consumedDelayed { consumeDelayedTrigger(p, id: id) }
            outcome.merge(result)
            if stopWhenPrevented && outcome.prevented { return outcome }
        }
        return outcome
    }

    mutating func consumeDelayedTrigger(_ p: Int, id: Int) {
        guard let index = players[p].flags.delayedTriggers.firstIndex(where: { $0.id == id }) else { return }
        players[p].flags.delayedTriggers[index].charges -= 1
        if players[p].flags.delayedTriggers[index].charges <= 0 {
            players[p].flags.delayedTriggers.remove(at: index)
        }
    }

    mutating func expireEndOfTurnTriggers() {
        for side in players.indices where players[side].flags.delayedTriggers.contains(where: { $0.expiry == .endOfTurn }) {
            players[side].flags.delayedTriggers.removeAll { $0.expiry == .endOfTurn }
        }
    }

    @discardableResult
    mutating func announce(_ event: GameEvent, aboutUnit uid: Int, owner p: Int, stopWhenPrevented: Bool = false) -> EventOutcome {
        var outcome = EventOutcome()
        guard let current = unit(p, uid) else { return outcome }
        let location = CardLocation.field(uid: uid)
        outcome.merge(send(event, to: current.cardId, owner: p, at: location, relation: .itself))
        if stopWhenPrevented && outcome.prevented { return outcome }
        if let gears = unit(p, uid)?.gears, !gears.isEmpty {
            outcome.merge(sendToGears(event, owner: p, gears: gears, host: .unit(uid), stopWhenPrevented: stopWhenPrevented))
            if stopWhenPrevented && outcome.prevented { return outcome }
        }
        outcome.merge(broadcast(event, to: p, subject: location, includeSubject: false, stopWhenPrevented: stopWhenPrevented))
        return outcome
    }
}
