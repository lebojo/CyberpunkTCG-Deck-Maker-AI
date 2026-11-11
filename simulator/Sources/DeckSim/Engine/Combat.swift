extension Game {
    mutating func performAttack(_ p: Int, attackerUid: Int, target initialTarget: AttackTarget) {
        guard unitIndex(p, attackerUid) != nil else { return }
        spendUnit(p, uid: attackerUid)
        note("P\(p) attacks with \(card(players[p].field[unitIndex(p, attackerUid)!].cardId).name)")
        onAttackDeclared(p, uid: attackerUid)
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

    mutating func onAttackDeclared(_ p: Int, uid: Int) {
        guard let index = unitIndex(p, uid) else { return }
        let unit = players[p].field[index]
        let unitCard = card(unit.cardId)
        switch unitCard.behavior {
        case .goroUnit:
            if allLegendsFaceUp(p) { players[p].field[index].bonusPower += 5 }
        case .huscle:
            if power(p, players[p].field[index], attacking: true) >= 5 { draw(p, 1) }
        case .ripper:
            searchTopForGear(p)
        case .pepe:
            if valuePairs(p) >= 1 {
                var readied = 0
                for slot in players[p].legends.indices where readied < 2 && players[p].legends[slot].spent && players[p].legends[slot].faceUp && card(players[p].legends[slot].cardId).isMerc {
                    players[p].legends[slot].spent = false
                    readied += 1
                }
            }
        case .dexter:
            adjustGigBest(p, maxDelta: 1)
        case .placide:
            placideBottomDeck(p)
        default:
            break
        }
        if unitCard.isArasaka, faceUpLegend(p, .yorinobu), !players[p].flags.yorinobuUsed {
            players[p].flags.yorinobuUsed = true
            draw(p, 1)
            if let sc = streetCred(p), sc < 20 { discardWorst(p) }
        }
    }

    mutating func searchTopForGear(_ p: Int) {
        var top: [Int] = []
        for _ in 0..<3 { if let id = players[p].deck.popLast() { top.append(id) } }
        let pick = top.filter { card($0).kind == .gear }.max { keepValue(p, $0) < keepValue(p, $1) }
        var rest = top
        if let pick, let position = rest.firstIndex(of: pick) {
            rest.remove(at: position)
            addToHand(p, pick)
        }
        bottomDeck(p, rest)
    }

    mutating func discardWorst(_ p: Int) {
        guard let index = players[p].hand.indices.min(by: { keepValue(p, players[p].hand[$0]) < keepValue(p, players[p].hand[$1]) }) else { return }
        players[p].trash.append(players[p].hand.remove(at: index))
    }

    mutating func react(defender: Int, attacker: Int, attackerUid: Int, target: inout AttackTarget, stealPenalty: inout Int) {
        guard let attackerIndex = unitIndex(attacker, attackerUid) else { return }
        let attackingUnit = players[attacker].field[attackerIndex]
        let attackPower = power(attacker, attackingUnit, attacking: true)

        let unblockable = card(attackingUnit.cardId).behavior == .flathead && hasLessStreetCred(attacker)
        var blocker: FieldUnit?
        if !unblockable {
            blocker = bestBlocker(defender: defender, attackPower: attackPower, attackerCard: card(attackingUnit.cardId), target: target)
        }
        if case .gigs = target, blocker == nil || blockerIsChump(blocker!, attackPower: attackPower, defender: defender) {
            if stealCount(forPower: attackPower) > 0, let tcIndex = players[defender].hand.firstIndex(where: { card($0).behavior == .takeControl }),
               effectiveCost(defender, card(players[defender].hand[tcIndex])) <= availableMana(defender) {
                if pay(defender, effectiveCost(defender, card(players[defender].hand[tcIndex]))) {
                    players[defender].trash.append(players[defender].hand.remove(at: tcIndex))
                    players[defender].flags.programsPlayed += 1
                    stealPenalty += 1
                    note("P\(defender) plays Take Control")
                    if stealCount(forPower: attackPower) - stealPenalty <= 0 { return }
                }
            }
        }
        if let blocker {
            spendUnit(defender, uid: blocker.uid)
            switch card(blocker.cardId).behavior {
            case .negotiators: discardWorst(attacker)
            case .laLlorona: increaseGigBest(defender, by: 3)
            default: break
            }
            note("P\(defender) blocks with \(card(blocker.cardId).name)")
            target = .unit(blocker.uid)
        }
        if case .unit(let defenderUid) = target {
            useFightTricks(defender: defender, attacker: attacker, attackerUid: attackerUid, defenderUid: defenderUid)
        }
    }

    func blockerIsChump(_ blocker: FieldUnit, attackPower: Int, defender: Int) -> Bool {
        power(defender, blocker, attacking: false) < attackPower
    }

    func bestBlocker(defender: Int, attackPower: Int, attackerCard: Card, target: AttackTarget) -> FieldUnit? {
        let candidates = players[defender].field.filter { isBlocker($0) && !$0.spent }
        var best: (unit: FieldUnit, score: Double)?
        let stealN = stealCount(forPower: attackPower)
        let rivalGigs = players[1 - defender].gigs.count
        let defenderOnTheEdge = rivalGigs + stealN >= 6
        for candidate in candidates {
            if case .unit(let uid) = target, uid == candidate.uid { continue }
            let blockPower = power(defender, candidate, attacking: false)
            let cost = Double(card(candidate.cardId).costValue)
            var score: Double?
            if blockPower > attackPower {
                score = 30 - cost
            } else if blockPower == attackPower && blockPower > 0 {
                score = 12 - cost + Double(attackerCard.costValue)
            } else if case .gigs = target, stealN > 0 {
                let saved = Double(stealN) * 8
                let loss = cost * 1.5
                if defenderOnTheEdge || saved >= loss { score = saved - loss + (defenderOnTheEdge ? 15 : 0) }
            }
            if let score, score > 0, score > (best?.score ?? 0) { best = (candidate, score) }
        }
        return best?.unit
    }

    struct FightJudgment: Sendable {
        let attackPower: Int
        let defendPower: Int
        let attackerWins: Bool
        let defenderWins: Bool
    }

    func judge(attackPower: Int, defendPower: Int, attackerUnit: FieldUnit, defenderUnit: FieldUnit) -> FightJudgment {
        let attackerCard = card(attackerUnit.cardId)
        let defenderCard = card(defenderUnit.cardId)
        var attack = attackPower
        var defend = defendPower
        if attackerCard.behavior == .meredith, defenderUnit.isLegend { attack += 2 }
        if defenderCard.behavior == .meredith, attackerUnit.isLegend { defend += 2 }
        var attackerWins = attack > defend
        var defenderWins = defend > attack
        if attackerCard.behavior == .johnny, defenderCard.isCorpo { attackerWins = true; defenderWins = false }
        if defenderCard.behavior == .johnny, attackerCard.isCorpo { defenderWins = true; attackerWins = false }
        return FightJudgment(attackPower: attack, defendPower: defend, attackerWins: attackerWins, defenderWins: defenderWins)
    }

    func currentJudgment(attacker: Int, attackerUid: Int, defenderUid: Int, attackDelta: Int = 0, defendDelta: Int = 0) -> FightJudgment? {
        guard let attackerIndex = unitIndex(attacker, attackerUid), let defenderIndex = unitIndex(1 - attacker, defenderUid) else { return nil }
        let attackerUnit = players[attacker].field[attackerIndex]
        let defenderUnit = players[1 - attacker].field[defenderIndex]
        return judge(
            attackPower: power(attacker, attackerUnit, attacking: true) + attackerUnit.fightBonus + attackDelta,
            defendPower: power(1 - attacker, defenderUnit, attacking: false) + defenderUnit.fightBonus + defendDelta,
            attackerUnit: attackerUnit,
            defenderUnit: defenderUnit
        )
    }

    func fightScore(_ judgment: FightJudgment, side: Int, attacker: Int) -> Int {
        let wins = side == attacker ? judgment.attackerWins : judgment.defenderWins
        let rivalWins = side == attacker ? judgment.defenderWins : judgment.attackerWins
        if wins { return 2 }
        return rivalWins ? 0 : 1
    }

    enum FightTrick: Sendable {
        case floorIt(handIndex: Int)
        case synapse(handIndex: Int, bonus: Int)
        case dumDum(slot: Int, bonus: Int)
        case safetyOverride(handIndex: Int)
    }

    func availableFightTricks(side: Int, ownUid: Int) -> [(trick: FightTrick, cost: Int)] {
        var tricks: [(FightTrick, Int)] = []
        let mana = availableMana(side)
        for (index, id) in players[side].hand.enumerated() {
            let c = card(id)
            guard c.kind == .program else { continue }
            let cost = effectiveCost(side, c)
            guard cost <= mana else { continue }
            switch c.behavior {
            case .floorIt:
                tricks.append((.floorIt(handIndex: index), cost))
            case .synapseBurnout:
                let legends = players[side].legends.filter { $0.faceUp }.count
                if legends > 0 { tricks.append((.synapse(handIndex: index, bonus: legends), cost)) }
            case .safetyOverride:
                tricks.append((.safetyOverride(handIndex: index), cost))
            default:
                break
            }
        }
        if let ownIndex = unitIndex(side, ownUid), mana >= 1,
           let slot = players[side].legends.firstIndex(where: { $0.faceUp && !$0.spent && card($0.cardId).behavior == .dumDum }) {
            let gears = players[side].field[ownIndex].gears.count
            if gears > 0 { tricks.append((.dumDum(slot: slot, bonus: gears), 1)) }
        }
        return tricks
    }

    mutating func perform(_ trick: FightTrick, side: Int, ownUid: Int, otherUid: Int) {
        switch trick {
        case .floorIt(let handIndex):
            guard let otherIndex = unitIndex(1 - side, otherUid), payProgram(side, handIndex: handIndex) else { return }
            players[1 - side].field[otherIndex].bonusPower -= 1
            draw(side, 1)
        case .synapse(let handIndex, let bonus):
            guard let ownIndex = unitIndex(side, ownUid), payProgram(side, handIndex: handIndex) else { return }
            players[side].field[ownIndex].fightBonus += bonus
        case .dumDum(let slot, let bonus):
            guard unitIndex(side, ownUid) != nil, pay(side, 1) else { return }
            if !players[side].legends[slot].spent { spendLegend(side, slot) }
            if let freshIndex = unitIndex(side, ownUid) { players[side].field[freshIndex].bonusPower += bonus }
        case .safetyOverride(let handIndex):
            guard payProgram(side, handIndex: handIndex) else { return }
            players[side].flags.safetyOverrides += 1
        }
    }

    mutating func payProgram(_ side: Int, handIndex: Int) -> Bool {
        guard players[side].hand.indices.contains(handIndex) else { return false }
        let id = players[side].hand[handIndex]
        let cost = effectiveCost(side, card(id))
        guard pay(side, cost) else { return false }
        players[side].hand.remove(at: handIndex)
        players[side].trash.append(id)
        players[side].flags.programsPlayed += 1
        note("P\(side) plays \(card(id).name)")
        return true
    }

    mutating func useFightTricks(defender: Int, attacker: Int, attackerUid: Int, defenderUid: Int) {
        var side = defender
        var idleTurns = 0
        for _ in 0..<8 {
            let acted = tryFightTrick(side: side, attacker: attacker, attackerUid: attackerUid, defenderUid: defenderUid)
            idleTurns = acted ? 0 : idleTurns + 1
            if idleTurns >= 2 { return }
            side = 1 - side
        }
    }

    mutating func tryFightTrick(side: Int, attacker: Int, attackerUid: Int, defenderUid: Int) -> Bool {
        guard let before = currentJudgment(attacker: attacker, attackerUid: attackerUid, defenderUid: defenderUid) else { return false }
        let currentScore = fightScore(before, side: side, attacker: attacker)
        guard currentScore < 2 else { return false }
        let ownUid = side == attacker ? attackerUid : defenderUid
        let otherUid = side == attacker ? defenderUid : attackerUid
        var best: (trick: FightTrick, gain: Int, cost: Int)?
        for (trick, cost) in availableFightTricks(side: side, ownUid: ownUid) {
            var gain = 0
            switch trick {
            case .floorIt:
                let delta = side == attacker ? (0, -1) : (-1, 0)
                if let after = currentJudgment(attacker: attacker, attackerUid: attackerUid, defenderUid: defenderUid, attackDelta: delta.0, defendDelta: delta.1) {
                    gain = fightScore(after, side: side, attacker: attacker) - currentScore
                }
            case .synapse(_, let bonus), .dumDum(_, let bonus):
                let delta = side == attacker ? (bonus, 0) : (0, bonus)
                if let after = currentJudgment(attacker: attacker, attackerUid: attackerUid, defenderUid: defenderUid, attackDelta: delta.0, defendDelta: delta.1) {
                    gain = fightScore(after, side: side, attacker: attacker) - currentScore
                }
            case .safetyOverride:
                if players[side].flags.safetyOverrides == 0, currentScore == 0 { gain = 1 }
            }
            if gain > 0, gain > (best?.gain ?? 0) || (gain == best?.gain && cost < (best?.cost ?? Int.max)) {
                best = (trick, gain, cost)
            }
        }
        guard let choice = best else { return false }
        perform(choice.trick, side: side, ownUid: ownUid, otherUid: otherUid)
        return true
    }

    mutating func resolveSteal(_ p: Int, attackerUid: Int, penalty: Int) {
        guard let index = unitIndex(p, attackerUid) else { return }
        let attackingUnit = players[p].field[index]
        let rival = 1 - p
        let count = max(0, stealCount(forPower: power(p, attackingUnit, attacking: true)) - penalty)
        guard count > 0, !players[rival].gigs.isEmpty else { return }
        var stolen: [Gig] = []
        var pool = players[rival].gigs
        for _ in 0..<count {
            guard let pickIndex = pool.indices.max(by: { gigStealPriority(p, pool[$0]) < gigStealPriority(p, pool[$1]) }) else { break }
            let gig = pool.remove(at: pickIndex)
            if intercepts(rival, gig: gig) { continue }
            stolen.append(gig)
        }
        completeSteal(p, attackerUid: attackerUid, stolen: stolen)
    }

    mutating func intercepts(_ rival: Int, gig: Gig) -> Bool {
        guard fieldHas(rival, .altMother),
              let index = players[rival].hand.firstIndex(where: { card($0).costValue == gig.value }) else { return false }
        players[rival].trash.append(players[rival].hand.remove(at: index))
        return true
    }

    mutating func completeSteal(_ p: Int, attackerUid: Int, stolen: [Gig]) {
        let rival = 1 - p
        var remaining = stolen
        for gig in stolen {
            if let position = players[rival].gigs.firstIndex(where: { $0.sides == gig.sides && $0.value == gig.value }) {
                players[rival].gigs.remove(at: position)
                players[p].gigs.append(gig)
            } else {
                remaining.removeAll { $0.sides == gig.sides && $0.value == gig.value }
            }
        }
        guard !stolen.isEmpty else { return }
        note("P\(p) steals \(stolen.count) gig(s) -> P\(p) \(players[p].gigs.count) / P\(rival) \(players[rival].gigs.count)")
        guard let index = unitIndex(p, attackerUid) else { checkOvertimeWin(); return }
        let attackingUnit = players[p].field[index]
        let attackerCard = card(attackingUnit.cardId)
        if attackerCard.behavior == .goons, !attackingUnit.gears.isEmpty, !players[rival].hand.isEmpty { discardWorst(rival) }
        if attackingUnit.gears.contains(where: { card($0).behavior == .gorillaArms }), !attackingUnit.stoleThisTurn {
            players[p].field[index].stoleThisTurn = true
            let mine = Set(players[p].gigs.map { $0.value })
            if let extra = players[rival].gigs.filter({ !mine.contains($0.value) }).max(by: { gigStealPriority(p, $0) < gigStealPriority(p, $1) }),
               let position = players[rival].gigs.firstIndex(where: { $0.sides == extra.sides && $0.value == extra.value }) {
                players[rival].gigs.remove(at: position)
                players[p].gigs.append(extra)
                if extra.sides == 6 { triggerRecruits(p) }
            }
        }
        for gig in stolen where gig.sides == 6 { triggerRecruits(p) }
        checkOvertimeWin()
    }

    mutating func triggerRecruits(_ p: Int) {
        for _ in 0..<players[p].field.filter({ card($0.cardId).behavior == .sixthStreetRecruits }).count {
            increaseGigBest(p, by: 6)
        }
    }

    mutating func resolveFight(_ p: Int, attackerUid: Int, defenderUid: Int) {
        let rival = 1 - p
        guard let judgment = currentJudgment(attacker: p, attackerUid: attackerUid, defenderUid: defenderUid),
              let attackerIndex = unitIndex(p, attackerUid), let defenderIndex = unitIndex(rival, defenderUid) else { return }
        let attackerCard = card(players[p].field[attackerIndex].cardId)
        let defenderCard = card(players[rival].field[defenderIndex].cardId)
        let attackPower = judgment.attackPower
        let defendPower = judgment.defendPower
        let attackerWins = judgment.attackerWins
        let defenderWins = judgment.defenderWins
        let attackerLoses = !attackerWins
        let defenderLoses = !defenderWins
        note("fight \(attackerCard.name) (\(attackPower)) vs \(defenderCard.name) (\(defendPower))")

        var toDefeat: [(owner: Int, uid: Int)] = []
        if defenderLoses && attackPower > 0 { toDefeat.append((rival, defenderUid)) }
        if attackerLoses && defendPower > 0 { toDefeat.append((p, attackerUid)) }
        if defenderLoses && players[rival].flags.safetyOverrides > 0 {
            players[rival].flags.safetyOverrides -= 1
            if !toDefeat.contains(where: { $0.uid == attackerUid }) { toDefeat.append((p, attackerUid)) }
        }
        if attackerLoses && players[p].flags.safetyOverrides > 0 {
            players[p].flags.safetyOverrides -= 1
            if !toDefeat.contains(where: { $0.uid == defenderUid }) { toDefeat.append((rival, defenderUid)) }
        }
        if attackerWins { rewardFightWin(p, uid: attackerUid) }
        if defenderWins { rewardFightWin(rival, uid: defenderUid) }
        for entry in toDefeat { defeat(entry.owner, uid: entry.uid) }
    }

    mutating func rewardFightWin(_ owner: Int, uid: Int) {
        guard let index = unitIndex(owner, uid) else { return }
        let unit = players[owner].field[index]
        for gear in unit.gears where card(gear).behavior == .satori { draw(owner, 1) }
        if card(unit.cardId).behavior == .johnny, !unit.readiedByWin {
            players[owner].field[index].spent = false
            players[owner].field[index].readiedByWin = true
        }
    }
}
