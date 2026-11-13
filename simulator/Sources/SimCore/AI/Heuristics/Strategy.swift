enum MainAction: Sendable {
    case ability(AbilityUse)
    case play(handIndex: Int)
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
        useAbilities(p, timing: .beforeAttacks)
        attackPhase(p)
        if isOver { return }
        developBoard(p)
        callLegendIfUseful(p)
        useAbilities(p, timing: .endOfMainPhase)
    }

    mutating func sellIfUseful(_ p: Int) {
        guard !players[p].flags.sold else { return }
        let totalEddies = players[p].eddiesReady + players[p].eddiesSpent
        guard players[p].hand.count >= 2, totalEddies < 6 || players[p].hand.count >= 6 else { return }
        let sellable = players[p].hand.indices.filter { stats(players[p].hand[$0]).isSellable && stats(players[p].hand[$0]).kind != .legend }
        guard let index = sellable.min(by: { keepValue(p, players[p].hand[$0]) < keepValue(p, players[p].hand[$1]) }) else { return }
        sellFromHand(p, handIndex: index)
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
            case .ability(let use):
                activate(p, use)
            case .play(let handIndex):
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
        let mainUses = abilityUses(p, timing: .mainAction)
        for use in mainUses where isLegendSource(use) {
            consider(.ability(use), use.option.value)
        }
        let mana = availableMana(p)
        for (index, id) in players[p].hand.enumerated() {
            guard stats(id).kind != .legend, effectiveCost(p, id) <= mana else { continue }
            if let value = playValue(p, id) { consider(.play(handIndex: index), value) }
        }
        for slot in players[p].legends.indices {
            if let value = goSoloValue(p, slot: slot) { consider(.goSolo(slot: slot), value) }
        }
        for use in mainUses where !isLegendSource(use) {
            consider(.ability(use), use.option.value)
        }
        return best?.action
    }

    func isLegendSource(_ use: AbilityUse) -> Bool {
        if case .legend = use.source { return true }
        return false
    }

    mutating func playChosenCard(_ p: Int, handIndex: Int) {
        let id = players[p].hand[handIndex]
        prepareToPlay(p, id)
        playFromHand(p, handIndex: handIndex)
    }

    mutating func prepareToPlay(_ p: Int, _ id: Int) {
        guard let use = firstAbilityUse(p, timing: .beforePlayingCard, subject: .card(id)) else { return }
        activate(p, use, subject: .card(id))
    }

    func goSoloValue(_ p: Int, slot: Int) -> Double? {
        let legend = players[p].legends[slot]
        let legendProfile = profile(legend.cardId)
        guard !legend.spent, legendProfile.keywords.contains(.goSolo),
              let cost = goSoloCost(p, slot: slot), !players[1 - p].gigs.isEmpty else { return nil }
        let otherMana = availableMana(p) - 1
        guard cost <= otherMana else { return nil }
        let total = legendPower(p, slot: slot)
        guard total >= 8 else { return nil }
        let steals = stealCount(forPower: total)
        return 18 + Double(total) * 1.5 + Double(steals) * 6 + legendProfile.hints.goSoloBonus
    }

    mutating func attackPhase(_ p: Int) {
        var iterations = 0
        while iterations < 14, !isOver {
            iterations += 1
            guard let choice = bestAttack(p) else { return }
            prepareAttack(p, uid: choice.uid)
            performAttack(p, attackerUid: choice.uid, target: choice.target)
        }
    }

    func bestAttack(_ p: Int) -> (uid: Int, target: AttackTarget, value: Double)? {
        var best: (uid: Int, target: AttackTarget, value: Double)?
        let rival = 1 - p
        let rivalBlockers = players[rival].field.filter { isBlocker(rival, $0) && !$0.spent }
        let desperate = overtime || turn >= 12 || players[rival].gigs.count >= 5
        for unit in attackersAvailable(p) {
            let unitHints = profile(unit.cardId).hints
            let myPower = power(p, unit, attacking: true)
            let unitValue = unitThreat(p, unit)
            let exposure = players[rival].field.filter { !$0.spent && power(rival, $0, attacking: true) >= myPower && myPower > 0 }.count
            let shielded = unit.gears.contains { profile($0).hints.ignoresExposure }
            let exposurePenalty: Double = shielded ? 0 : (desperate ? 0.05 : 0.25) * unitValue * Double(min(exposure, 2))
            if canStealGigs(p, unit) {
                let steals = min(stealCount(forPower: myPower), players[rival].gigs.count)
                var value = Double(steals) * 30
                if players[p].gigs.count + steals >= 7 { value += 80 }
                value += attackValueBonus(p, unit)
                if steals == 0 { value = unitHints.attackWithoutStealValue }
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

    func attackValueBonus(_ p: Int, _ unit: FieldUnit) -> Double {
        implementation(unit.cardId).attackValueBonus(in: query(unit.cardId, owner: p, at: .field(uid: unit.uid), subject: .unit(owner: p, uid: unit.uid), attacking: true))
    }

    mutating func prepareAttack(_ p: Int, uid: Int) {
        useAbilities(p, timing: .beforeAttack, subject: .attack(owner: p, uid: uid))
    }
}
