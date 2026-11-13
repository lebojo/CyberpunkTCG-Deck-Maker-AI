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

    @discardableResult
    mutating func setGigToMatchBest(_ p: Int) -> Bool {
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
        guard let choice = best else { return false }
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
}
