extension Game {
    mutating func performAttack(_ p: Int, attackerUid: Int, target initialTarget: AttackTarget) {
        guard let attacker = unit(p, attackerUid) else { return }
        spendUnit(p, uid: attackerUid)
        note("P\(p) attacks with \(name(attacker.cardId))")
        announce(.attackDeclared(attackerUid: attackerUid, target: initialTarget), aboutUnit: attackerUid, owner: p)
        guard unitIndex(p, attackerUid) != nil, !isOver else { return }
        if case .unit(let defenderUid) = initialTarget, unitIndex(1 - p, defenderUid) == nil { return }

        var target = initialTarget
        var stealPenalty = 0
        react(defender: 1 - p, attacker: p, attackerUid: attackerUid, target: &target, stealPenalty: &stealPenalty)
        guard unitIndex(p, attackerUid) != nil, !isOver else { return }

        switch target {
        case .gigs:
            resolveSteal(p, attackerUid: attackerUid, penalty: stealPenalty)
        case .unit(let defenderUid):
            resolveFight(p, attackerUid: attackerUid, defenderUid: defenderUid)
        }
    }

    mutating func react(defender: Int, attacker: Int, attackerUid: Int, target: inout AttackTarget, stealPenalty: inout Int) {
        guard let attackingUnit = unit(attacker, attackerUid) else { return }
        let attackPower = power(attacker, attackingUnit, attacking: true)

        var blocker: FieldUnit?
        if !isUnblockable(attackingUnit, owner: attacker) {
            blocker = bestBlocker(defender: defender, attackPower: attackPower, attackerCard: attackingUnit.cardId, target: target)
        }
        if case .gigs = target, blocker == nil || blockerIsChump(blocker!, attackPower: attackPower, defender: defender) {
            if stealCount(forPower: attackPower) > 0 {
                stealPenalty += useStealReaction(defender: defender, attacker: attacker, attackerUid: attackerUid)
                if stealPenalty > 0 && stealCount(forPower: attackPower) - stealPenalty <= 0 { return }
            }
        }
        if let blocker {
            spendUnit(defender, uid: blocker.uid)
            announce(.blocked(blockerUid: blocker.uid, attackerUid: attackerUid), aboutUnit: blocker.uid, owner: defender)
            note("P\(defender) blocks with \(name(blocker.cardId))")
            target = .unit(blocker.uid)
        }
        if case .unit(let defenderUid) = target {
            useFightTricks(defender: defender, attacker: attacker, attackerUid: attackerUid, defenderUid: defenderUid)
        }
    }

    func blockerIsChump(_ blocker: FieldUnit, attackPower: Int, defender: Int) -> Bool {
        power(defender, blocker, attacking: false) < attackPower
    }

    mutating func resolveSteal(_ p: Int, attackerUid: Int, penalty: Int) {
        guard let attackingUnit = unit(p, attackerUid) else { return }
        let rival = 1 - p
        let count = max(0, stealCount(forPower: power(p, attackingUnit, attacking: true)) - penalty)
        guard count > 0, !players[rival].gigs.isEmpty else { return }
        var stolen: [Gig] = []
        var pool = players[rival].gigs
        for _ in 0..<count {
            guard let pickIndex = pool.indices.max(by: { gigStealPriority(p, pool[$0]) < gigStealPriority(p, pool[$1]) }) else { break }
            let gig = pool.remove(at: pickIndex)
            if gigIsProtected(rival, gig: gig, attackerUid: attackerUid) { continue }
            stolen.append(gig)
        }
        completeSteal(p, attackerUid: attackerUid, stolen: stolen)
    }

    mutating func gigIsProtected(_ rival: Int, gig: Gig, attackerUid: Int) -> Bool {
        guard listenersInPlay.contains(.gigWouldBeStolen) || !players[rival].flags.delayedTriggers.isEmpty else { return false }
        return broadcast(.gigWouldBeStolen(gig, attackerUid: attackerUid), to: rival, stopWhenPrevented: true).prevented
    }

    @discardableResult
    mutating func moveGig(_ gig: Gig, from rival: Int, to p: Int) -> Bool {
        guard let position = players[rival].gigs.firstIndex(where: { $0.sides == gig.sides && $0.value == gig.value }) else { return false }
        players[rival].gigs.remove(at: position)
        players[p].gigs.append(gig)
        return true
    }

    mutating func completeSteal(_ p: Int, attackerUid: Int, stolen: [Gig]) {
        let rival = 1 - p
        var taken: [Gig] = []
        for gig in stolen where moveGig(gig, from: rival, to: p) { taken.append(gig) }
        guard !stolen.isEmpty else { return }
        note("P\(p) steals \(stolen.count) gig(s) -> P\(p) \(players[p].gigs.count) / P\(rival) \(players[rival].gigs.count)")
        guard unitIndex(p, attackerUid) != nil else { checkOvertimeWin(); return }
        announce(.stoleGigs(attackerUid: attackerUid, gigs: stolen), aboutUnit: attackerUid, owner: p)
        for gig in stolen { announceGigStolen(p, gig: gig, attackerUid: attackerUid) }
        checkOvertimeWin()
    }

    mutating func announceGigStolen(_ p: Int, gig: Gig, attackerUid: Int) {
        guard listenersInPlay.contains(.gigStolen) || !players[p].flags.delayedTriggers.isEmpty else { return }
        broadcast(.gigStolen(gig, attackerUid: attackerUid), to: p, subject: .field(uid: attackerUid))
    }

    mutating func stealExtraGig(_ p: Int, attackerUid: Int, choosing pick: (Game) -> Gig?) {
        let rival = 1 - p
        guard let extra = pick(self), moveGig(extra, from: rival, to: p) else { return }
        announceGigStolen(p, gig: extra, attackerUid: attackerUid)
    }

    mutating func resolveFight(_ p: Int, attackerUid: Int, defenderUid: Int) {
        let rival = 1 - p
        guard let judgment = currentJudgment(attacker: p, attackerUid: attackerUid, defenderUid: defenderUid),
              let attackerUnit = unit(p, attackerUid), let defenderUnit = unit(rival, defenderUid) else { return }
        let attackPower = judgment.attackPower
        let defendPower = judgment.defendPower
        let attackerLoses = !judgment.attackerWins
        let defenderLoses = !judgment.defenderWins
        note("fight \(name(attackerUnit.cardId)) (\(attackPower)) vs \(name(defenderUnit.cardId)) (\(defendPower))")

        var toDefeat: [UnitRef] = []
        func schedule(_ entry: UnitRef) {
            if !toDefeat.contains(where: { $0.uid == entry.uid }) { toDefeat.append(entry) }
        }
        if defenderLoses && attackPower > 0 { toDefeat.append(UnitRef(owner: rival, uid: defenderUid)) }
        if attackerLoses && defendPower > 0 { toDefeat.append(UnitRef(owner: p, uid: attackerUid)) }
        let attackerReport = FightReport(unitUid: attackerUid, opponentUid: defenderUid, power: attackPower, opponentPower: defendPower)
        let defenderReport = FightReport(unitUid: defenderUid, opponentUid: attackerUid, power: defendPower, opponentPower: attackPower)
        if defenderLoses {
            announce(.lostFight(defenderReport), aboutUnit: defenderUid, owner: rival).defeatsAfterFight.forEach(schedule)
        }
        if attackerLoses {
            announce(.lostFight(attackerReport), aboutUnit: attackerUid, owner: p).defeatsAfterFight.forEach(schedule)
        }
        if judgment.attackerWins { announce(.wonFight(attackerReport), aboutUnit: attackerUid, owner: p) }
        if judgment.defenderWins { announce(.wonFight(defenderReport), aboutUnit: defenderUid, owner: rival) }
        for entry in toDefeat {
            let opponent = entry.uid == attackerUid ? defenderUid : attackerUid
            defeat(entry.owner, uid: entry.uid, cause: .fight(opponentUid: opponent))
        }
    }
}
