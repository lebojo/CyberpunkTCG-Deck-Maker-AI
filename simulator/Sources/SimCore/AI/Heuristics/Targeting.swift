public struct GearTarget: Sendable, Hashable {
    public let owner: Int
    public let host: EquipTarget
    public let gear: Int
}

extension Game {
    func unitThreat(_ owner: Int, _ unit: FieldUnit) -> Double {
        var score = Double(power(owner, unit, attacking: true)) * 1.5 + Double(stats(unit.cardId).costValue)
        score += Double(unit.gears.count) * 2
        if isBlocker(owner, unit) { score += 3 }
        score += profile(unit.cardId).hints.threatBonus
        if unit.isLegend { score += 4 }
        return score
    }

    func bestRivalUnit(_ p: Int, where filter: (FieldUnit) -> Bool) -> FieldUnit? {
        players[1 - p].field.filter(filter).max { unitThreat(1 - p, $0) < unitThreat(1 - p, $1) }
    }

    func worstRivalUnit(_ p: Int, where filter: (FieldUnit) -> Bool) -> FieldUnit? {
        players[1 - p].field.filter(filter).min { power(1 - p, $0, attacking: false) < power(1 - p, $1, attacking: false) }
    }

    func bestRivalGear(_ p: Int, where filter: (Int) -> Bool) -> GearTarget? {
        var best: (target: GearTarget, priority: Int)?
        let rival = 1 - p
        for unit in players[rival].field {
            for gear in unit.gears where filter(gear) {
                let priority = profile(gear).hints.gearRemovalPriority
                if priority > (best?.priority ?? -1) { best = (GearTarget(owner: rival, host: .unit(unit.uid), gear: gear), priority) }
            }
        }
        for (slot, legend) in players[rival].legends.enumerated() where legend.faceUp {
            for gear in legend.gears where filter(gear) {
                let priority = profile(gear).hints.gearRemovalPriority
                if priority > (best?.priority ?? -1) { best = (GearTarget(owner: rival, host: .legend(slot), gear: gear), priority) }
            }
        }
        return best?.target
    }

    func equipTarget(_ p: Int, gear: Int) -> EquipTarget? {
        equipTargets(p, gear: gear).first?.target
    }

    func equipTargets(_ p: Int, gear: Int) -> [(target: EquipTarget, score: Double)] {
        var options: [(target: EquipTarget, score: Double)] = []
        let gearPower = stats(gear).power
        for unit in players[p].field {
            let current = power(p, unit, attacking: true)
            let unitHints = profile(unit.cardId).hints
            let gain = gearPower + unitHints.extraPowerPerGear
            var score = Double(unit.gears.count) * -0.4 + Double(current) * 0.2
            let crosses = stealCount(forPower: current + gain) > stealCount(forPower: current)
            if crosses { score += 8 }
            if !unit.spent && !unit.lagging { score += 3 }
            if unit.lagging { score += 1 }
            if unitHints.prefersNoGears { score -= 2 }
            if current == 0 && gearPower == 0 { score -= 3 }
            if unit.spent { score -= 1 }
            options.append((.unit(unit.uid), score))
        }
        let carrierInDeck = players[p].legends.contains { profile($0.cardId).hints.carriesGearsAsLegend }
        let gearSuitsLegend = profile(gear).hints.suitsFaceUpLegend
        for (slot, legend) in players[p].legends.enumerated() where legend.faceUp {
            let isCarrier = profile(legend.cardId).hints.carriesGearsAsLegend
            var score = -2.0
            if isCarrier && legend.gears.count < 4 { score = 5 + Double(legend.gears.count) }
            if carrierInDeck && !isCarrier { continue }
            if gearSuitsLegend && !isCarrier { score = max(score, 0.5) }
            options.append((.legend(slot), score))
        }
        return options.sorted { $0.score > $1.score }
    }
}
