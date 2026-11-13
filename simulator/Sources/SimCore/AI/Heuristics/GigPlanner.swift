extension Game {
    func gigScore(_ gigs: [Gig], wantsMin: Bool) -> Double {
        var score = 0.0
        let groups = Dictionary(grouping: gigs, by: { $0.value })
        score += Double(groups.values.reduce(0) { $0 + $1.count / 2 }) * 3
        if wantsMin { score += Double(gigs.filter { $0.isMin }.count) * 4 }
        if gigs.contains(where: { $0.value >= 8 }) { score += 1.5 }
        if groups.count >= 3 { score += 1 }
        if !wantsMin { score += Double(gigs.reduce(0) { $0 + $1.value }) * 0.05 }
        return score
    }

    func bestAdjustment(_ p: Int, up: Int, down: Int) -> (index: Int, value: Int)? {
        let gigs = players[p].gigs
        let wantsMin = players[p].wantsMinGigs
        let baseline = gigScore(gigs, wantsMin: wantsMin)
        var best: (index: Int, value: Int, score: Double)?
        for index in gigs.indices {
            let gig = gigs[index]
            let low = max(1, gig.value - down)
            let high = min(gig.sides, gig.value + up)
            guard low <= high else { continue }
            for value in low...high where value != gig.value {
                var trial = gigs
                trial[index].value = value
                let score = gigScore(trial, wantsMin: wantsMin)
                if score > baseline, score > (best?.score ?? -1) { best = (index, value, score) }
            }
        }
        return best.map { ($0.index, $0.value) }
    }

    @discardableResult
    mutating func adjustGigBest(_ p: Int, maxDelta: Int) -> Bool {
        guard let choice = bestAdjustment(p, up: maxDelta, down: maxDelta) else { return false }
        adjustGig(p, index: choice.index, to: choice.value)
        return true
    }

    @discardableResult
    mutating func increaseGigBest(_ p: Int, by amount: Int) -> Bool {
        guard let choice = bestAdjustment(p, up: amount, down: 0) else { return false }
        adjustGig(p, index: choice.index, to: choice.value)
        return true
    }

    @discardableResult
    mutating func decreaseGigBest(_ p: Int, by amount: Int) -> Bool {
        guard let choice = bestAdjustment(p, up: 0, down: amount) else { return false }
        adjustGig(p, index: choice.index, to: choice.value)
        return true
    }

    func bestMatchingSet(_ p: Int) -> (index: Int, value: Int)? {
        let gigs = players[p].gigs
        let wantsMin = players[p].wantsMinGigs
        let baseline = gigScore(gigs, wantsMin: wantsMin)
        var best: (index: Int, value: Int, score: Double)?
        for index in gigs.indices {
            for other in gigs.indices where other != index {
                let value = gigs[other].value
                guard value != gigs[index].value, value <= gigs[index].sides else { continue }
                var trial = gigs
                trial[index].value = value
                let score = gigScore(trial, wantsMin: wantsMin)
                if score > baseline, score > (best?.score ?? -1) { best = (index, value, score) }
            }
        }
        return best.map { ($0.index, $0.value) }
    }

    @discardableResult
    mutating func setGigToMatchBest(_ p: Int) -> Bool {
        guard let choice = bestMatchingSet(p) else { return false }
        adjustGig(p, index: choice.index, to: choice.value)
        return true
    }

    func gigStealPriority(_ owner: Int, _ gig: Gig) -> Double {
        var score = Double(gig.value) * 0.1
        if players[owner].wantsMinGigs && gig.isMin { score += 5 }
        if players[owner].gigs.contains(where: { $0.value == gig.value }) { score += 3 }
        if gig.value >= 8 { score += 1 }
        return score
    }

    func bestGigSwap(_ p: Int, margin: Double) -> (mine: Int, theirs: Int)? {
        let wantsMin = players[p].wantsMinGigs
        let baseline = gigScore(players[p].gigs, wantsMin: wantsMin)
        var best: (mine: Int, theirs: Int, score: Double)?
        for i in players[p].gigs.indices {
            for j in players[1 - p].gigs.indices {
                var trial = players[p].gigs
                trial[i] = players[1 - p].gigs[j]
                let score = gigScore(trial, wantsMin: wantsMin)
                if score > baseline + margin, score > (best?.score ?? 0) { best = (i, j, score) }
            }
        }
        return best.map { ($0.mine, $0.theirs) }
    }

    func bestNetGigSwap(_ p: Int) -> (mine: Int, theirs: Int)? {
        let mine = players[p].gigs
        let theirs = players[1 - p].gigs
        guard !mine.isEmpty, !theirs.isEmpty else { return nil }
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
        return best.map { ($0.own, $0.rival) }
    }
}
