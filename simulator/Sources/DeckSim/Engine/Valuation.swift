extension Game {
    func keepValue(_ p: Int, _ id: Int) -> Double {
        let c = card(id)
        switch c.kind {
        case .unit:
            var value = 14 + Double(c.costValue) * 0.8
            switch c.behavior {
            case .goroUnit, .pepe, .lizzyWizzy, .saulBright, .minotaur: value += 4
            case .bombus, .voodooBoy, .corpoSecurity: value -= 2
            default: break
            }
            return value
        case .gear:
            var value = 8 + Double(c.power)
            if players[p].field.isEmpty { value -= 2 }
            switch c.behavior {
            case .mantis, .satori, .sandevistan: value += 2
            case .kiroshi, .mandibular: value -= 2
            default: break
            }
            return value
        case .program:
            switch c.behavior {
            case .takeControl: return 12
            case .floorIt: return 10
            case .safetyOverride: return 9
            case .cyberpsychosis: return 11
            default: break
            }
            if let value = programValue(p, c) { return min(value * 0.5, 14) }
            return 4
        case .legend:
            return 0
        }
    }

    func programValue(_ p: Int, _ c: Card) -> Double? {
        let rivalHasUnits = !players[1 - p].field.isEmpty
        switch c.behavior {
        case .afterparty:
            if players[p].gigs.count >= 2 && distinctGigValues(p) >= 2 { return 14 }
            return bestAdjustment(p, up: 1, down: 1) != nil ? 8 : nil
        case .allIsLost:
            return 10
        case .chromeReverie:
            guard players[1 - p].field.contains(where: { !$0.spent && power(1 - p, $0, attacking: true) > 0 }) else { return nil }
            return 26 + (minGigCount(p) >= 1 && !players[p].flags.called ? 8 : 0)
        case .corporateSurveillance:
            return players[1 - p].field.contains(where: { !$0.spent && card($0.cardId).costValue <= 4 }) ? 30 : nil
        case .detonate:
            return detonateTarget(p) != nil ? 26 : nil
        case .floorIt:
            return rivalHasUnits ? 10 : nil
        case .industrialAssembly:
            guard !players[p].gigs.isEmpty else { return nil }
            return bestAdjustment(p, up: 4, down: 0) != nil ? 14 : nil
        case .overTheEdge:
            guard let limit = players[p].gigs.first(where: { $0.sides == 20 })?.value else { return nil }
            return players[1 - p].field.contains(where: { power(1 - p, $0, attacking: false) <= limit }) ? 34 : nil
        case .peaceOffering:
            guard players[p].gigs.count >= 2 else { return nil }
            return gigScoreAfterMatch(p) ? 16 : nil
        case .pyramidSong:
            if players[p].gigs.contains(where: { $0.sides == 4 && $0.isMin }),
               players[1 - p].field.contains(where: { power(1 - p, $0, attacking: false) <= 4 }) { return 36 }
            return players[1 - p].field.contains(where: { power(1 - p, $0, attacking: false) == 0 }) ? 24 : nil
        case .heist:
            return 18
        case .threeMouths:
            return 24
        case .towerfall:
            let weak = players[1 - p].field.filter { power(1 - p, $0, attacking: false) <= 5 }.count
            if hasLessStreetCred(p), weak >= 1 { return 20 + Double(weak) * 12 }
            let zero = players[1 - p].field.filter { power(1 - p, $0, attacking: false) == 0 }.count
            return zero >= 1 ? 16 + Double(zero) * 6 : nil
        case .trustNoOne:
            guard !players[p].gigs.isEmpty else { return nil }
            if bestAdjustment(p, up: 0, down: 3) != nil { return players[p].wantsMinGigs ? 22 : 9 }
            return minGigCount(p) >= 1 ? 9 : nil
        case .wildInTheStreets:
            return players[1 - p].field.contains(where: { $0.spent }) ? 34 : nil
        case .lesElemens:
            guard let worst = worstRivalUnit(p, where: { _ in true }) else { return nil }
            return card(worst.cardId).costValue >= 3 ? 20 : 10
        case .bootleg:
            return hasEvenAndOddGig(p) ? 22 : 10
        case .nocturne:
            let discounted = players[p].fixer.isEmpty
            return (discounted ? 22 : 14) + (players[1 - p].gigs.count > players[p].gigs.count ? 4 : 0)
        case .synapseBurnout:
            let legends = players[p].legends.filter { $0.faceUp }.count
            guard legends > 0, players[1 - p].field.contains(where: { $0.spent }),
                  players[p].field.contains(where: { canAttackAtAll(p, $0) }) else { return nil }
            return 12 + Double(legends) * 4
        case .cyberpsychosis, .takeControl, .safetyOverride:
            return nil
        default:
            return 8
        }
    }

    func gigScoreAfterMatch(_ p: Int) -> Bool {
        var probe = self
        return probe.setGigToMatchBest(p)
    }

    func unitPlayValue(_ p: Int, _ c: Card) -> Double {
        var value = 20 + Double(c.power) * 1.2 + Double(c.costValue) * 1.5
        if turn <= 8 && c.costValue <= 3 { value += 4 }
        switch c.behavior {
        case .corpoSecurity: value += 2
        case .bombus: value -= 6
        case .ripper: value -= 2
        case .voodooBoy:
            let hasProgram = players[p].hand.contains { card($0).kind == .program }
            value += hasProgram || players[p].flags.programsPlayed > 0 ? 4 : -6
        case .malfini:
            value += players[1 - p].field.contains(where: { !$0.spent }) ? 12 : -14
        case .oda:
            value += valuePairs(p) >= 1 && players[1 - p].field.contains(where: { !$0.spent }) ? 12 : 0
        case .minotaur:
            value += hasMoreStreetCred(p) && players[1 - p].field.contains(where: { power(1 - p, $0, attacking: false) <= 5 }) ? 12 : 0
        case .kusanagi:
            value += players[1 - p].gigs.isEmpty ? -10 : 6
        case .lizzyWizzy:
            let hasTarget = players[p].hand.contains { card($0).kind == .program && card($0).costValue <= 3 } || players[p].trash.contains { card($0).kind == .program && card($0).costValue <= 3 }
            value += hasTarget ? 6 : 0
        case .laLlorona, .negotiators: value += 2
        case .mamanBrigitte:
            let programs = players[p].hand.filter { card($0).kind == .program }.count
            value += programs >= 2 && players[1 - p].field.contains(where: { $0.gears.isEmpty }) ? 8 : 0
        case .maxTacAV: value += players[1 - p].gigs.isEmpty ? 0 : 3
        case .goroUnit: value += allLegendsFaceUp(p) ? 8 : 0
        case .saulBright: value += players[p].field.count >= 2 ? 8 : 0
        default: break
        }
        return value
    }

    func gearPlayValue(_ p: Int, _ c: Card) -> Double? {
        guard equipTarget(p, gear: c) != nil else { return nil }
        var value = 24 + Double(c.power) * 2
        switch c.behavior {
        case .mandibular: value += 4
        case .sandevistan, .satori, .zetatech: value += 3
        case .kiroshi: value -= 3
        case .gorillaArms: value += 4
        case .relic: value += players[p].trash.contains(where: { card($0).kind == .unit }) ? 5 : 0
        default: break
        }
        return value
    }

    func openingHandScore(_ p: Int, _ ids: [Int]) -> Double {
        let hand = ids.map { card($0) }.filter { $0.kind != .legend }
        let cheapPlays = hand.filter { $0.costValue <= 3 }.count
        let units = hand.filter { $0.kind == .unit && $0.costValue <= 4 }.count
        let gears = hand.filter { $0.kind == .gear && $0.costValue <= 2 }.count
        let sellables = hand.filter { $0.sellable }.count
        let heavy = hand.filter { $0.costValue >= 6 }.count
        var score = Double(min(cheapPlays, 4)) * 3
        score += Double(min(units, 2)) * 4
        score += units > 0 && gears > 0 ? 3 : 0
        score += Double(min(sellables, 3)) * 2
        score -= Double(max(heavy - 1, 0)) * 4
        score -= sellables < 2 ? 5 : 0
        return score
    }

    mutating func shouldMulligan(_ p: Int) -> Bool {
        let handSize = players[p].hand.count
        let pool = players[p].hand + players[p].deck
        guard pool.count > handSize else { return false }
        let current = openingHandScore(p, players[p].hand)
        let samples = 40
        var scores: [Double] = []
        for _ in 0..<samples {
            var shuffled = pool
            shuffled.shuffle(using: &rng)
            scores.append(openingHandScore(p, Array(shuffled.prefix(handSize))))
        }
        let mean = scores.reduce(0, +) / Double(samples)
        let variance = scores.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(samples)
        return current < mean - 0.5 * variance.squareRoot()
    }
}
