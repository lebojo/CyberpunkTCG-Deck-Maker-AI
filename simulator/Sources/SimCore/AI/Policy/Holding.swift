extension Game {
    mutating func holdMainPhase(_ p: Int, reserve: Int, attacks: Bool) {
        sellIfUseful(p)
        developBoard(p, reserve: reserve)
        if reserve == 0 { useAbilities(p, timing: .beforeAttacks) }
        if attacks { attackPhase(p, keepBlockersHome: true) }
        if isOver { return }
        developBoard(p, reserve: reserve)
        finishHolding(p, reserve: reserve)
        note("P\(p) \(reserve > 0 ? "bluffe : garde \(reserve) mana ouvert et ses Units prêtes" : "garde ses Blockers à la maison")")
    }

    mutating func finishHolding(_ p: Int, reserve: Int) {
        if availableMana(p) > reserve { callLegendIfUseful(p) }
        if reserve == 0 { useAbilities(p, timing: .endOfMainPhase) }
    }

    func bluffReserve(_ p: Int) -> Int? {
        guard policies[p].config.bluff, !policies[p].config.legacy, let cheapest = cheapestQuickInDeckList(of: p) else { return nil }
        let reserve = max(1, cheapest)
        return reserve <= availableMana(p) ? reserve : nil
    }

    func canGuardHome(_ p: Int) -> Bool {
        guard !policies[p].config.legacy else { return false }
        return attackersAvailable(p).contains { isBlocker(p, $0) }
    }

    func holdingActions(_ p: Int) -> [SearchAction] {
        var actions: [SearchAction] = []
        if canGuardHome(p) { actions.append(.guardHome) }
        if let reserve = bluffReserve(p) { actions.append(.bluff(reserve: reserve)) }
        return actions
    }
}
