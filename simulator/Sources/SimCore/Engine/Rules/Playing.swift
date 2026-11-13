extension Game {
    func effectiveCost(_ p: Int, _ played: Card) -> Int {
        var cost = played.costValue
        if played.behavior == .nocturne && players[p].fixer.isEmpty { cost = 1 }
        if played.kind == .program && players[p].flags.programDiscount > 0 {
            cost = max(1, cost - players[p].flags.programDiscount)
        }
        if played.kind == .gear && played.isCyberware && !players[p].flags.cyberwareDiscountUsed && fieldHas(p, .viktorDrop) {
            cost = max(1, cost - 3)
        }
        return cost
    }

    mutating func jackieTrigger(_ p: Int, _ played: Card) {
        guard played.isBlue, played.kind == .unit || played.kind == .gear,
              faceUpLegend(p, .jackie), !players[p].flags.jackieUsed else { return }
        players[p].flags.jackieUsed = true
        guard let choice = bestAdjustment(p, up: 0, down: 2) else { return }
        adjustGig(p, index: choice.index, to: choice.value)
        if choice.value == 1 { draw(p, 1) }
    }

    mutating func equip(_ p: Int, gear: Int, to target: EquipTarget) {
        switch target {
        case .unit(let uid):
            if let index = unitIndex(p, uid) { players[p].field[index].gears.append(gear) }
        case .legend(let slot):
            if players[p].legends.indices.contains(slot) { players[p].legends[slot].gears.append(gear) }
        }
    }

    @discardableResult
    mutating func playFromHand(_ p: Int, handIndex: Int, equipTo: EquipTarget? = nil, free: Bool = false) -> Bool {
        guard players[p].hand.indices.contains(handIndex) else { return false }
        let id = players[p].hand[handIndex]
        let played = card(id)
        let cost = free ? 0 : effectiveCost(p, played)
        guard cost <= availableMana(p) else { return false }
        if played.kind == .gear {
            guard let target = equipTo ?? equipTarget(p, gear: played) else { return false }
            guard pay(p, cost) else { return false }
            players[p].hand.remove(at: handIndex)
            if played.isCyberware && fieldHas(p, .viktorDrop) { players[p].flags.cyberwareDiscountUsed = true }
            equip(p, gear: id, to: target)
            note("P\(p) equips \(played.name)")
            jackieTrigger(p, played)
            return true
        }
        guard pay(p, cost) else { return false }
        players[p].hand.remove(at: handIndex)
        switch played.kind {
        case .unit:
            let uid = takeUid()
            players[p].field.append(FieldUnit(uid: uid, cardId: id, isLegend: false))
            note("P\(p) plays \(played.name)")
            jackieTrigger(p, played)
            onUnitPlayed(p, uid: uid)
        case .program:
            playProgram(p, id, bottomAfter: false)
        default:
            break
        }
        return true
    }

    mutating func playProgram(_ p: Int, _ id: Int, bottomAfter: Bool) {
        let program = card(id)
        players[p].flags.programsPlayed += 1
        players[p].flags.programDiscount = 0
        note("P\(p) plays \(program.name)")
        resolveProgram(p, program)
        if bottomAfter { bottomDeck(p, [id]) } else { players[p].trash.append(id) }
        checkOvertimeWin()
    }

    mutating func onUnitPlayed(_ p: Int, uid: Int) {
        guard let index = unitIndex(p, uid) else { return }
        let unitCard = card(players[p].field[index].cardId)
        switch unitCard.behavior {
        case .fieldOperator:
            if let sc = streetCred(p), sc % 2 == 0 { draw(p, 1) }
        case .minotaur:
            if hasMoreStreetCred(p), let target = bestRivalUnit(p, where: { power(1 - p, $0, attacking: false) <= 5 }) {
                defeat(1 - p, uid: target.uid)
            }
        case .malfini:
            spendUnit(p, uid: uid)
            if let target = bestRivalUnit(p, where: { !$0.spent }) { spendUnit(1 - p, uid: target.uid) }
        case .oda:
            for _ in 0..<valuePairs(p) {
                if let target = bestRivalUnit(p, where: { !$0.spent }) { spendUnit(1 - p, uid: target.uid) }
            }
        case .placide:
            placideBottomDeck(p)
        case .dexter:
            adjustGigBest(p, maxDelta: 1)
        case .lizzyWizzy:
            lizzyFreeProgram(p)
        case .adamSmasher:
            if let target = bestRivalUnit(p, where: { _ in true }) { defeat(1 - p, uid: target.uid) }
        case .mamanBrigitte:
            mamanBrigitteBottomDeck(p)
        case .maxTacAV:
            swapBestGigs(p)
        default:
            break
        }
    }

    mutating func placideBottomDeck(_ p: Int) {
        guard let target = bestRivalUnit(p, where: { _ in true }),
              let discardIndex = players[p].hand.indices.filter({ card(players[p].hand[$0]).kind == .program })
                .min(by: { keepValue(p, players[p].hand[$0]) < keepValue(p, players[p].hand[$1]) }),
              keepValue(p, players[p].hand[discardIndex]) < 14 else { return }
        let discarded = players[p].hand.remove(at: discardIndex)
        players[p].trash.append(discarded)
        bottomDeckUnit(1 - p, uid: target.uid)
    }

    mutating func lizzyFreeProgram(_ p: Int) {
        var best: (fromHand: Bool, index: Int, value: Double)?
        for (index, id) in players[p].hand.enumerated() where card(id).kind == .program && card(id).costValue <= 3 {
            if let value = programValue(p, card(id)), value > (best?.value ?? 0) { best = (true, index, value) }
        }
        for (index, id) in players[p].trash.enumerated() where card(id).kind == .program && card(id).costValue <= 3 {
            if let value = programValue(p, card(id)), value > (best?.value ?? 0) { best = (false, index, value) }
        }
        guard let choice = best else { return }
        let id = choice.fromHand ? players[p].hand.remove(at: choice.index) : players[p].trash.remove(at: choice.index)
        playProgram(p, id, bottomAfter: true)
    }

    mutating func resolveProgram(_ p: Int, _ program: Card) {
        switch program.behavior {
        case .afterparty:
            if let choice = bestAdjustment(p, up: 1, down: 1) { adjustGig(p, index: choice.index, to: choice.value) }
            if players[p].gigs.count >= 2 && distinctGigValues(p) >= 2 { draw(p, 1) }
        case .allIsLost:
            let milled = trashTop(p, 3)
            let pick = milled.filter { card($0).kind == .unit }.max { card($0).costValue < card($1).costValue }
            for id in milled { if id == pick, let pick { addToHand(p, pick) } else { players[p].trash.append(id) } }
        case .chromeReverie:
            if let target = bestRivalUnit(p, where: { _ in true }), let index = unitIndex(1 - p, target.uid) {
                players[1 - p].field[index].cannotAttackBefore = turn + 2
            }
            if minGigCount(p) >= 1, !players[p].flags.called,
               let slot = players[p].legends.indices.first(where: { !players[p].legends[$0].faceUp }) {
                callLegend(p, slot, free: true)
            }
        case .corporateSurveillance:
            if let target = bestRivalUnit(p, where: { !$0.spent && card($0.cardId).costValue <= 4 }) { spendUnit(1 - p, uid: target.uid) }
        case .detonate:
            if let target = detonateTarget(p) { destroyGear(1 - p, target) }
        case .floorIt:
            if let target = bestRivalUnit(p, where: { _ in true }), let index = unitIndex(1 - p, target.uid) {
                players[1 - p].field[index].bonusPower -= 1
            }
            draw(p, 1)
        case .industrialAssembly:
            increaseGigBest(p, by: 4)
            if hasGigAtLeast(p, 8) { draw(p, 1) }
        case .overTheEdge:
            if let limit = players[p].gigs.first(where: { $0.sides == 20 })?.value,
               let target = bestRivalUnit(p, where: { power(1 - p, $0, attacking: false) <= limit }) {
                defeat(1 - p, uid: target.uid)
            }
        case .peaceOffering:
            setGigToMatchBest(p)
            if valuePairs(p) >= 1 { draw(p, 1) }
        case .pyramidSong:
            resolvePyramidSong(p)
        case .safetyOverride:
            players[p].flags.safetyOverrides += 1
        case .heist:
            let milled = trashTop(p, 4)
            let gear = milled.filter { card($0).kind == .gear }.max { card($0).power < card($1).power }
            for id in milled where id != gear { players[p].trash.append(id) }
            if let gear {
                let free = players[p].gigs.contains { $0.value == card(gear).costValue }
                players[p].hand.append(gear)
                if free, let index = players[p].hand.lastIndex(of: gear) { playFromHand(p, handIndex: index, free: true) }
            }
        case .threeMouths:
            var top: [Int] = []
            for _ in 0..<3 { if let id = players[p].deck.popLast() { top.append(id) } }
            let take = min(top.count, 1 + minGigCount(p))
            let ranked = top.sorted { keepValue(p, $0) > keepValue(p, $1) }
            for id in ranked.prefix(take) { addToHand(p, id, revealed: false) }
            bottomDeck(p, Array(ranked.dropFirst(take)))
        case .towerfall:
            resolveTowerfall(p)
        case .trustNoOne:
            decreaseGigBest(p, by: 3)
            if minGigCount(p) >= 1 { draw(p, 1) }
        case .wildInTheStreets:
            if let target = bestRivalUnit(p, where: { $0.spent }) { defeat(1 - p, uid: target.uid) }
        case .lesElemens:
            if let target = worstRivalUnit(p, where: { _ in true }) { bottomDeckUnit(1 - p, uid: target.uid) }
        case .bootleg:
            sellTopOfDeck(p)
            if hasEvenAndOddGig(p) { draw(p, 2) }
        case .nocturne:
            resolveNocturne(p)
        case .synapseBurnout:
            resolveSynapseBurnout(p)
        case .cyberpsychosis, .takeControl:
            break
        default:
            break
        }
    }

    mutating func sellTopOfDeck(_ p: Int) {
        guard let id = players[p].deck.popLast() else { return }
        if card(id).sellable && card(id).kind != .legend {
            players[p].eddiesReady += 1
            players[p].trash.append(id)
        } else {
            players[p].deck.append(id)
        }
    }

    func hasEvenAndOddGig(_ p: Int) -> Bool {
        let gigs = players[p].gigs
        return gigs.contains { $0.value % 2 == 0 } && gigs.contains { $0.value % 2 == 1 }
    }

    mutating func resolveNocturne(_ p: Int) {
        let threat = players[1 - p].field.filter { !$0.spent && power(1 - p, $0, attacking: true) >= 6 }
        let behind = players[1 - p].gigs.count > players[p].gigs.count
        if behind, let target = threat.max(by: { power(1 - p, $0, attacking: true) < power(1 - p, $1, attacking: true) }),
           let index = unitIndex(1 - p, target.uid) {
            players[1 - p].field[index].cannotAttackBefore = turn + 2
        } else {
            draw(p, 2)
        }
    }

    mutating func resolveSynapseBurnout(_ p: Int) {
        let legends = players[p].legends.filter { $0.faceUp }.count
        guard legends > 0 else { return }
        let candidates = players[p].field.filter { canAttackAtAll(p, $0) }
        guard let best = candidates.max(by: { power(p, $0, attacking: true) < power(p, $1, attacking: true) }),
              let index = unitIndex(p, best.uid) else { return }
        players[p].field[index].fightBonus += legends
    }

    mutating func mamanBrigitteBottomDeck(_ p: Int) {
        let programs = players[p].hand.indices.filter { card(players[p].hand[$0]).kind == .program }
            .sorted { keepValue(p, players[p].hand[$0]) < keepValue(p, players[p].hand[$1]) }
        guard programs.count >= 2,
              keepValue(p, players[p].hand[programs[0]]) + keepValue(p, players[p].hand[programs[1]]) < 20,
              let target = bestRivalUnit(p, where: { $0.gears.isEmpty }) else { return }
        for index in programs.prefix(2).sorted(by: >) {
            players[p].trash.append(players[p].hand.remove(at: index))
        }
        bottomDeckUnit(1 - p, uid: target.uid)
    }

    mutating func swapBestGigs(_ p: Int) {
        let mine = players[p].gigs
        let theirs = players[1 - p].gigs
        guard !mine.isEmpty, !theirs.isEmpty else { return }
        var best: (own: Int, rival: Int, net: Double)?
        let ownBefore = gigScore(mine, wantsMin: players[p].wantsMinGigs)
        let rivalBefore = gigScore(theirs, wantsMin: players[1 - p].wantsMinGigs)
        for own in mine.indices {
            for rival in theirs.indices where mine[own].value != theirs[rival].value {
                var ownAfter = mine
                var rivalAfter = theirs
                ownAfter[own] = theirs[rival]
                rivalAfter[rival] = mine[own]
                let gain = gigScore(ownAfter, wantsMin: players[p].wantsMinGigs) - ownBefore
                let loss = gigScore(rivalAfter, wantsMin: players[1 - p].wantsMinGigs) - rivalBefore
                let net = gain - loss
                if net > 1, net > (best?.net ?? 0) { best = (own, rival, net) }
            }
        }
        guard let choice = best else { return }
        let given = players[p].gigs[choice.own]
        players[p].gigs[choice.own] = players[1 - p].gigs[choice.rival]
        players[1 - p].gigs[choice.rival] = given
        note("P\(p) swaps a Gig with the rival")
        if fieldHas(1 - p, .meredith) { meredithRecover(1 - p) }
    }

    mutating func meredithRecover(_ p: Int) {
        guard let best = players[p].trash.enumerated().max(by: { keepValue(p, $0.element) < keepValue(p, $1.element) }) else { return }
        let id = players[p].trash.remove(at: best.offset)
        addToHand(p, id)
    }

    mutating func destroyGear(_ owner: Int, _ target: (uid: Int?, slot: Int?, gear: Int)) {
        if let uid = target.uid, let index = unitIndex(owner, uid), let position = players[owner].field[index].gears.firstIndex(of: target.gear) {
            players[owner].field[index].gears.remove(at: position)
            players[owner].trash.append(target.gear)
        } else if let slot = target.slot, players[owner].legends.indices.contains(slot),
                  let position = players[owner].legends[slot].gears.firstIndex(of: target.gear) {
            players[owner].legends[slot].gears.remove(at: position)
            players[owner].trash.append(target.gear)
        }
    }

    mutating func resolvePyramidSong(_ p: Int) {
        let both = players[p].gigs.contains { $0.sides == 4 && $0.isMin }
        if both, let target = bestRivalUnit(p, where: { power(1 - p, $0, attacking: false) <= 4 }), let index = unitIndex(1 - p, target.uid) {
            players[1 - p].field[index].bonusPower -= 4
            bottomDeckUnit(1 - p, uid: target.uid)
            return
        }
        if let target = bestRivalUnit(p, where: { power(1 - p, $0, attacking: false) == 0 }) {
            bottomDeckUnit(1 - p, uid: target.uid)
        }
    }

    mutating func resolveTowerfall(_ p: Int) {
        let both = hasLessStreetCred(p)
        if both {
            for index in players[1 - p].field.indices { players[1 - p].field[index].bonusPower -= 5 }
        }
        for unit in players[1 - p].field where power(1 - p, unit, attacking: false) == 0 {
            bottomDeckUnit(1 - p, uid: unit.uid)
        }
    }
}
