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
        if faceUpLegend(p, .hanako) { draw(p, valuePairs(p)) }
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
        for index in players[p].field.indices { players[p].field[index].spent = false }
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
    }

    mutating func endTurn(_ p: Int) {
        for index in players[p].field.indices {
            let unit = players[p].field[index]
            if unit.gears.contains(where: { card($0).behavior == .sandevistan }) { players[p].field[index].spent = false }
        }
        for slot in players[p].legends.indices where players[p].legends[slot].gears.contains(where: { card($0).behavior == .sandevistan }) {
            players[p].legends[slot].spent = false
        }
        if fieldHas(p, .saulBright) {
            let spent = players[p].field.filter { $0.spent }.sorted { power(p, $0, attacking: true) > power(p, $1, attacking: true) }
            for unit in spent.prefix(3) {
                if let index = unitIndex(p, unit.uid) { players[p].field[index].spent = false }
            }
        }
        for unit in players[p].field where unit.defeatAtEnd {
            defeat(p, uid: unit.uid)
        }
        for unit in players[p].field where card(unit.cardId).behavior == .kusanagi {
            if let index = unitIndex(p, unit.uid) {
                let removed = players[p].field.remove(at: index)
                players[p].hand.append(removed.cardId)
                players[p].hand.append(contentsOf: removed.gears)
            }
        }
        for side in 0..<2 {
            for index in players[side].field.indices {
                players[side].field[index].bonusPower = 0
                players[side].field[index].fightBonus = 0
                players[side].field[index].lagging = false
                players[side].field[index].defeatAtEnd = false
                players[side].field[index].stoleThisTurn = false
                players[side].field[index].readiedByWin = false
            }
        }
        if emptyFixerStreak >= 2, !overtime {
            overtime = true
            note("overtime begins")
            checkOvertimeWin()
        }
        active = 1 - p
    }
}
