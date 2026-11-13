extension Game {
    mutating func playGame() {
        while !isOver { playTurn() }
    }

    mutating func playTurn() {
        turn += 1
        let p = active
        if turn > Game.turnLimit {
            outcome = .draw
            return
        }
        if players[p].gigs.count >= 7 {
            outcome = .win(player: p, reason: .gigsAtStart)
            return
        }
        readyPhase(p)
        players[p].flags = TurnFlags()
        draw(p, 1)
        if isOver { return }
        broadcast(.turnStarted, to: p)
        if isOver { return }
        rollIn(p)
        note("--- turn \(turn) P\(p): hand \(players[p].hand.count), eddies \(players[p].eddiesReady), gigs \(players[p].gigs.count)/\(players[1 - p].gigs.count)")
        runMainPhase(p)
        if isOver { return }
        endTurn(p)
    }

    mutating func readyPhase(_ p: Int) {
        players[p].eddiesReady += players[p].eddiesSpent
        players[p].eddiesSpent = 0
        if skipReadyOnce[p] {
            skipReadyOnce[p] = false
        } else {
            for slot in players[p].legends.indices { players[p].legends[slot].spent = false }
        }
        for index in players[p].field.indices where turn >= players[p].field[index].cannotReadyBefore {
            players[p].field[index].spent = false
        }
    }

    mutating func rollIn(_ p: Int) {
        if players[p].fixer.isEmpty {
            emptyFixerStreak += 1
            return
        }
        emptyFixerStreak = 0
        let nonTwenty = players[p].fixer.filter { $0 != 20 }
        let pool = nonTwenty.isEmpty ? players[p].fixer : nonTwenty
        let sides = players[p].wantsMinGigs ? pool.min()! : pool.max()!
        players[p].fixer.removeAll { $0 == sides }
        let value = Int.random(in: 1...sides, using: &rng)
        players[p].gigs.append(Gig(sides: sides, value: value))
        broadcast(.gigRolled(index: players[p].gigs.count - 1), to: p)
    }

    mutating func endTurn(_ p: Int) {
        resolveRequiredAttacks(p)
        if isOver { return }
        announceEndOfTurnToGears(p)
        for unit in players[p].field where unit.defeatAtEnd {
            defeat(p, uid: unit.uid)
        }
        broadcast(.endOfTurn, to: p)
        expireEndOfTurnTriggers()
        for side in 0..<2 {
            for index in players[side].field.indices { players[side].field[index].clearTurnState() }
        }
        if emptyFixerStreak >= 2, !overtime {
            overtime = true
            note("overtime begins")
            checkOvertimeWin()
        }
        active = 1 - p
    }

    mutating func announceEndOfTurnToGears(_ p: Int) {
        guard listenersInPlay.contains(.endOfTurn) else { return }
        let fieldHosts = players[p].field.filter { !$0.gears.isEmpty }.map { (EquipTarget.unit($0.uid), $0.gears) }
        for (host, gears) in fieldHosts { sendToGears(.endOfTurn, owner: p, gears: gears, host: host) }
        let legendHosts = players[p].legends.indices.filter { !players[p].legends[$0].gears.isEmpty }.map { (EquipTarget.legend($0), players[p].legends[$0].gears) }
        for (host, gears) in legendHosts { sendToGears(.endOfTurn, owner: p, gears: gears, host: host) }
    }

    mutating func resolveRequiredAttacks(_ p: Int) {
        let required = players[p].field.filter { $0.mustAttackOnTurn == turn }.map(\.uid)
        for uid in required {
            guard !isOver, let attacker = unit(p, uid), canAttackAtAll(p, attacker) else { continue }
            if canStealGigs(p, attacker) {
                performAttack(p, attackerUid: uid, target: .gigs)
            } else if let target = validUnitTargets(p, attacker).min(by: { power(1 - p, $0, attacking: false) < power(1 - p, $1, attacking: false) }) {
                performAttack(p, attackerUid: uid, target: .unit(target.uid))
            }
        }
    }

    mutating func checkOvertimeWin() {
        guard overtime, !isOver else { return }
        let order = [active, 1 - active]
        let winners = order.filter { players[$0].gigs.count >= 7 }
        if winners.count == 2 { outcome = .draw }
        else if let winner = winners.first { outcome = .win(player: winner, reason: .gigsInOvertime) }
    }
}
