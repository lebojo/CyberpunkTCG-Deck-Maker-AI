enum MainAction: Sendable {
    case riverWard(handIndex: Int)
    case play(handIndex: Int, priority: Double)
    case goSolo(slot: Int)
}

extension Game {
    mutating func runMainPhase(_ p: Int) {
        if searchPlayers[p] { searchMainPhase(p) } else { greedyMainPhase(p) }
    }

    mutating func greedyMainPhase(_ p: Int) {
        sellIfUseful(p)
        if availableMana(p) >= 2 { callLegendIfUseful(p) }
        developBoard(p)
        useHanako(p)
        attackPhase(p)
        if isOver { return }
        developBoard(p)
        callLegendIfUseful(p)
        replayProgramFromTrash(p)
    }

    mutating func sellIfUseful(_ p: Int) {
        guard !players[p].flags.sold else { return }
        let totalEddies = players[p].eddiesReady + players[p].eddiesSpent
        guard players[p].hand.count >= 2, totalEddies < 6 || players[p].hand.count >= 6 else { return }
        let sellable = players[p].hand.indices.filter { card(players[p].hand[$0]).sellable && card(players[p].hand[$0]).kind != .legend }
        guard let index = sellable.min(by: { keepValue(p, players[p].hand[$0]) < keepValue(p, players[p].hand[$1]) }) else { return }
        let sold = players[p].hand.remove(at: index)
        players[p].eddiesReady += 1
        players[p].flags.sold = true
        note("P\(p) sells \(card(sold).name)")
    }

    mutating func callLegendIfUseful(_ p: Int) {
        guard !players[p].flags.called, availableMana(p) >= 1,
              let slot = players[p].legends.indices.first(where: { !players[p].legends[$0].faceUp }) else { return }
        callLegend(p, slot, free: false)
    }

    mutating func developBoard(_ p: Int) {
        var guardCount = 0
        while guardCount < 40, !isOver {
            guardCount += 1
            guard let action = bestMainAction(p) else { return }
            switch action {
            case .riverWard(let handIndex):
                playRiverWardGear(p, handIndex: handIndex)
            case .play(let handIndex, _):
                playChosenCard(p, handIndex: handIndex)
            case .goSolo(let slot):
                goSolo(p, slot: slot)
            }
        }
    }

    func bestMainAction(_ p: Int) -> MainAction? {
        var best: (action: MainAction, value: Double)?
        func consider(_ action: MainAction, _ value: Double) {
            if value > (best?.value ?? 5) { best = (action, value) }
        }
        let mana = availableMana(p)
        if let wardSlot = players[p].legends.firstIndex(where: { $0.faceUp && !$0.spent && card($0.cardId).behavior == .riverWard }) {
            _ = wardSlot
            for (index, id) in players[p].hand.enumerated() where card(id).kind == .gear && card(id).costValue <= 2 {
                if let value = gearPlayValue(p, card(id)) { consider(.riverWard(handIndex: index), value + 40) }
            }
        }
        for (index, id) in players[p].hand.enumerated() {
            let c = card(id)
            let cost = effectiveCost(p, c)
            guard cost <= mana else { continue }
            switch c.kind {
            case .unit:
                consider(.play(handIndex: index, priority: 0), unitPlayValue(p, c))
            case .gear:
                if let value = gearPlayValue(p, c) { consider(.play(handIndex: index, priority: 0), value) }
            case .program:
                if let value = programValue(p, c) { consider(.play(handIndex: index, priority: 0), value) }
            case .legend:
                break
            }
        }
        for slot in players[p].legends.indices {
            if let value = goSoloValue(p, slot: slot) { consider(.goSolo(slot: slot), value) }
        }
        return best?.action
    }

    mutating func playChosenCard(_ p: Int, handIndex: Int) {
        let c = card(players[p].hand[handIndex])
        if c.kind == .program { prepareAltDiscount(p, c) }
        playFromHand(p, handIndex: handIndex)
    }

    mutating func prepareAltDiscount(_ p: Int, _ c: Card) {
        guard let slot = players[p].legends.firstIndex(where: { $0.faceUp && !$0.spent && card($0.cardId).behavior == .altSoulkiller }) else { return }
        let gain = min(minGigCount(p), c.costValue - 1)
        guard gain >= 2 else { return }
        spendLegend(p, slot)
        players[p].flags.programDiscount = minGigCount(p)
    }

    mutating func playRiverWardGear(_ p: Int, handIndex: Int) {
        guard let slot = players[p].legends.firstIndex(where: { $0.faceUp && !$0.spent && card($0.cardId).behavior == .riverWard }) else { return }
        guard playFromHand(p, handIndex: handIndex, free: true) else { return }
        spendLegend(p, slot)
    }

    func goSoloValue(_ p: Int, slot: Int) -> Double? {
        let legend = players[p].legends[slot]
        let legendCard = card(legend.cardId)
        guard legend.faceUp || !legend.faceUp, !legend.spent, legendCard.text.contains("{Go Solo}"),
              let cost = legendCard.cost, !players[1 - p].gigs.isEmpty else { return nil }
        let otherMana = availableMana(p) - 1
        guard cost <= otherMana else { return nil }
        let gearPower = legend.gears.reduce(0) { $0 + card($1).power }
        var total = legendCard.power + gearPower
        if legendCard.behavior == .royce { total += 2 * legend.gears.count }
        guard total >= 8 else { return nil }
        let steals = stealCount(forPower: total)
        var value = 18 + Double(total) * 1.5 + Double(steals) * 6
        if legendCard.behavior == .adamSmasher { value += 10 }
        return value
    }

    mutating func goSolo(_ p: Int, slot: Int) {
        guard players[p].legends.indices.contains(slot) else { return }
        let legend = players[p].legends[slot]
        guard let cost = card(legend.cardId).cost else { return }
        players[p].legends[slot].spent = true
        guard pay(p, cost) else {
            players[p].legends[slot].spent = legend.spent
            return
        }
        players[p].legends.remove(at: slot)
        let uid = takeUid()
        var unit = FieldUnit(uid: uid, cardId: legend.cardId, isLegend: true)
        unit.gears = legend.gears
        unit.lagging = false
        players[p].field.append(unit)
        note("P\(p) goes solo with \(card(legend.cardId).name)")
        onUnitPlayed(p, uid: uid)
    }

    mutating func useHanako(_ p: Int) {
        guard let slot = players[p].legends.firstIndex(where: { $0.faceUp && !$0.spent && card($0.cardId).behavior == .hanako }),
              !players[p].gigs.isEmpty, !players[1 - p].gigs.isEmpty else { return }
        let wantsMin = players[p].wantsMinGigs
        let baseline = gigScore(players[p].gigs, wantsMin: wantsMin)
        var best: (mine: Int, theirs: Int, score: Double)?
        for i in players[p].gigs.indices {
            for j in players[1 - p].gigs.indices {
                var trial = players[p].gigs
                trial[i] = players[1 - p].gigs[j]
                let score = gigScore(trial, wantsMin: wantsMin)
                if score > baseline + 2, score > (best?.score ?? 0) { best = (i, j, score) }
            }
        }
        guard let choice = best else { return }
        spendLegend(p, slot)
        let mine = players[p].gigs[choice.mine]
        players[p].gigs[choice.mine] = players[1 - p].gigs[choice.theirs]
        players[1 - p].gigs[choice.theirs] = mine
    }

    mutating func replayProgramFromTrash(_ p: Int) {
        guard !players[p].flags.altTrashUsed,
              let slot = players[p].legends.firstIndex(where: { $0.faceUp && !$0.spent && card($0.cardId).behavior == .altSoulkiller }) else { return }
        var best: (index: Int, value: Double)?
        for (index, id) in players[p].trash.enumerated() where card(id).kind == .program && card(id).costValue + 1 <= availableMana(p) - 1 {
            if let value = programValue(p, card(id)), value >= 18, value > (best?.value ?? 0) { best = (index, value) }
        }
        guard let choice = best else { return }
        let id = players[p].trash[choice.index]
        let cost = card(id).costValue
        guard pay(p, 1 + cost) else { return }
        players[p].flags.altTrashUsed = true
        players[p].trash.remove(at: choice.index)
        spendLegend(p, slot)
        playProgram(p, id, bottomAfter: true)
    }

    mutating func attackPhase(_ p: Int) {
        var iterations = 0
        while iterations < 14, !isOver {
            iterations += 1
            guard let choice = bestAttack(p) else { return }
            pumpBeforeAttack(p, uid: choice.uid)
            performAttack(p, attackerUid: choice.uid, target: choice.target)
        }
    }

    func bestAttack(_ p: Int) -> (uid: Int, target: AttackTarget, value: Double)? {
        var best: (uid: Int, target: AttackTarget, value: Double)?
        let rival = 1 - p
        let rivalBlockers = players[rival].field.filter { isBlocker($0) && !$0.spent }
        let desperate = overtime || turn >= 12 || players[rival].gigs.count >= 5
        for unit in attackersAvailable(p) {
            let unitCard = card(unit.cardId)
            let myPower = power(p, unit, attacking: true)
            let unitValue = unitThreat(p, unit)
            let exposure = players[rival].field.filter { !$0.spent && power(rival, $0, attacking: true) >= myPower && myPower > 0 }.count
            let exposurePenalty: Double = unit.gears.contains(where: { card($0).behavior == .sandevistan }) ? 0 : (desperate ? 0.05 : 0.25) * unitValue * Double(min(exposure, 2))
            if canStealGigs(p, unit) {
                let steals = min(stealCount(forPower: myPower), players[rival].gigs.count)
                var value = Double(steals) * 30
                if players[p].gigs.count + steals >= 7 { value += 80 }
                switch unitCard.behavior {
                case .ripper: value += 10
                case .huscle: value += myPower >= 5 ? 6 : 0
                case .goons: value += unit.gears.isEmpty ? 0 : 5
                default: break
                }
                if steals == 0 { value = unitCard.behavior == .ripper ? 6 : -10 }
                if !isUnblockable(unit, owner: p) {
                    let killers = rivalBlockers.filter { power(rival, $0, attacking: false) > myPower }
                    if !killers.isEmpty { value -= desperate ? unitValue * 0.2 : unitValue * 0.8 }
                    else if rivalBlockers.contains(where: { power(rival, $0, attacking: false) == myPower }) { value -= unitValue * 0.3 }
                }
                value -= exposurePenalty
                if value > (best?.value ?? 5) { best = (unit.uid, .gigs, value) }
            }
            for target in validUnitTargets(p, unit) {
                let targetPower = power(rival, target, attacking: false)
                let targetThreat = unitThreat(rival, target)
                var value: Double?
                if myPower > targetPower { value = targetThreat * 1.3 }
                else if myPower == targetPower && myPower > 0 { value = targetThreat - unitValue * 0.9 }
                guard var fightValue = value else { continue }
                fightValue -= exposurePenalty
                if !players[rival].gigs.isEmpty && canStealGigs(p, unit) { fightValue -= 6 }
                if fightValue > (best?.value ?? 5) { best = (unit.uid, .unit(target.uid), fightValue) }
            }
        }
        return best
    }

    func isUnblockable(_ unit: FieldUnit, owner: Int) -> Bool {
        card(unit.cardId).behavior == .flathead && hasLessStreetCred(owner)
    }

    mutating func pumpBeforeAttack(_ p: Int, uid: Int) {
        guard let index = unitIndex(p, uid) else { return }
        let unit = players[p].field[index]
        let current = power(p, unit, attacking: true)
        let gearCount = unit.gears.count
        guard gearCount > 0 else { return }
        if let slot = players[p].legends.firstIndex(where: { $0.faceUp && !$0.spent && card($0.cardId).behavior == .dumDum }),
           availableMana(p) >= 1 {
            let boosted = current + gearCount
            let rivalPower = players[1 - p].field.filter { isBlocker($0) && !$0.spent }.map { power(1 - p, $0, attacking: false) }
            let crosses = stealCount(forPower: boosted) > stealCount(forPower: current)
            let beatsBlocker = rivalPower.contains { $0 >= current && $0 < boosted }
            if crosses || beatsBlocker, pay(p, 1) {
                spendLegend(p, slot)
                players[p].field[index].bonusPower += gearCount
            }
        }
        if let handIndex = players[p].hand.firstIndex(where: { card($0).behavior == .cyberpsychosis }),
           gearCount >= 2, let freshIndex = unitIndex(p, uid), canStealGigs(p, players[p].field[freshIndex]) {
            let fresh = players[p].field[freshIndex]
            let currentNow = power(p, fresh, attacking: true)
            let boosted = currentNow + 3 * gearCount
            let steals = min(stealCount(forPower: boosted), players[1 - p].gigs.count)
            let cost = effectiveCost(p, card(players[p].hand[handIndex]))
            if players[p].gigs.count + steals >= 7, cost <= availableMana(p), pay(p, cost) {
                players[p].trash.append(players[p].hand.remove(at: handIndex))
                players[p].flags.programsPlayed += 1
                players[p].field[freshIndex].bonusPower += 3 * gearCount
                players[p].field[freshIndex].defeatAtEnd = true
                note("P\(p) plays Cyberpsychosis")
            }
        }
    }
}
