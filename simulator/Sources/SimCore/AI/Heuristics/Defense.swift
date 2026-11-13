extension Game {
    func bestBlocker(defender: Int, attackPower: Int, attackerCard: Int, target: AttackTarget) -> FieldUnit? {
        let candidates = players[defender].field.filter { !$0.spent && isBlocker(defender, $0) }
        var best: (unit: FieldUnit, score: Double)?
        let stealN = stealCount(forPower: attackPower)
        let rivalGigs = players[1 - defender].gigs.count
        let defenderOnTheEdge = rivalGigs + stealN >= 6
        for candidate in candidates {
            if case .unit(let uid) = target, uid == candidate.uid { continue }
            let blockPower = power(defender, candidate, attacking: false)
            let cost = Double(stats(candidate.cardId).costValue)
            var score: Double?
            if blockPower > attackPower {
                score = 30 - cost
            } else if blockPower == attackPower && blockPower > 0 {
                score = 12 - cost + Double(stats(attackerCard).costValue)
            } else if case .gigs = target, stealN > 0 {
                let saved = Double(stealN) * 8
                let loss = cost * 1.5
                if defenderOnTheEdge || saved >= loss { score = saved - loss + (defenderOnTheEdge ? 15 : 0) }
            }
            if let score, score > 0, score > (best?.score ?? 0) { best = (candidate, score) }
        }
        return best?.unit
    }
}
