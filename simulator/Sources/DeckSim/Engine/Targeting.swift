extension Game {
    func unitThreat(_ owner: Int, _ unit: FieldUnit) -> Double {
        let unitCard = card(unit.cardId)
        var score = Double(power(owner, unit, attacking: true)) * 1.5 + Double(unitCard.costValue)
        score += Double(unit.gears.count) * 2
        if isBlocker(unit) { score += 3 }
        switch unitCard.behavior {
        case .sandevistan, .saulBright, .pepe, .lizzyWizzy: score += 3
        default: break
        }
        if unit.isLegend { score += 4 }
        return score
    }

    func bestRivalUnit(_ p: Int, where filter: (FieldUnit) -> Bool) -> FieldUnit? {
        players[1 - p].field.filter(filter).max { unitThreat(1 - p, $0) < unitThreat(1 - p, $1) }
    }

    func worstRivalUnit(_ p: Int, where filter: (FieldUnit) -> Bool) -> FieldUnit? {
        players[1 - p].field.filter(filter).min { power(1 - p, $0, attacking: false) < power(1 - p, $1, attacking: false) }
    }

    func gearRemovalPriority(_ id: Int) -> Int {
        switch card(id).behavior {
        case .sandevistan: return 6
        case .satori: return 5
        case .zetatech: return 4
        case .mantis: return 3
        case .kiroshi: return 1
        default: return 2
        }
    }

    func detonateTarget(_ p: Int) -> (uid: Int?, slot: Int?, gear: Int)? {
        var best: (uid: Int?, slot: Int?, gear: Int, priority: Int)?
        for unit in players[1 - p].field {
            for gear in unit.gears where card(gear).power <= 2 {
                let priority = gearRemovalPriority(gear) + (power(1 - p, unit, attacking: true) >= 10 ? 0 : 0)
                if priority > (best?.priority ?? -1) { best = (unit.uid, nil, gear, priority) }
            }
        }
        for (slot, legend) in players[1 - p].legends.enumerated() where legend.faceUp {
            for gear in legend.gears where card(gear).power <= 2 {
                let priority = gearRemovalPriority(gear)
                if priority > (best?.priority ?? -1) { best = (nil, slot, gear, priority) }
            }
        }
        return best.map { ($0.uid, $0.slot, $0.gear) }
    }

    func equipTarget(_ p: Int, gear: Card) -> EquipTarget? {
        equipTargets(p, gear: gear).first?.target
    }

    func equipTargets(_ p: Int, gear: Card) -> [(target: EquipTarget, score: Double)] {
        var options: [(target: EquipTarget, score: Double)] = []
        for unit in players[p].field {
            let current = power(p, unit, attacking: true)
            let gain = gear.power + (card(unit.cardId).behavior == .royce ? 2 : 0)
            var score = Double(unit.gears.count) * -0.4 + Double(current) * 0.2
            let crosses = stealCount(forPower: current + gain) > stealCount(forPower: current)
            if crosses { score += 8 }
            if !unit.spent && !unit.lagging { score += 3 }
            if unit.lagging { score += 1 }
            if card(unit.cardId).behavior == .ripper || card(unit.cardId).behavior == .bombus { score -= 2 }
            if current == 0 && gear.power == 0 { score -= 3 }
            if unit.spent { score -= 1 }
            options.append((.unit(unit.uid), score))
        }
        let royceInDeck = players[p].legends.contains { card($0.cardId).behavior == .royce }
        for (slot, legend) in players[p].legends.enumerated() where legend.faceUp {
            let legendCard = card(legend.cardId)
            var score = -2.0
            if legendCard.behavior == .royce && legend.gears.count < 4 { score = 5 + Double(legend.gears.count) }
            if royceInDeck && legendCard.behavior != .royce { continue }
            if (gear.behavior == .zetatech || gear.behavior == .radioport || gear.behavior == .sandevistan) && legendCard.behavior != .royce { score = max(score, 0.5) }
            options.append((.legend(slot), score))
        }
        return options.sorted { $0.score > $1.score }
    }
}

extension Card {
    var gearBehavior: Behavior { behavior }
}
