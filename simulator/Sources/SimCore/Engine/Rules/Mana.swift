extension Game {
    func availableMana(_ p: Int) -> Int {
        players[p].legends.reduce(players[p].eddiesReady) { $1.spent ? $0 : $0 + 1 }
    }

    mutating func pay(_ p: Int, _ amount: Int) -> Bool {
        guard amount <= availableMana(p) else { return false }
        var remaining = amount
        let fromEddies = min(remaining, players[p].eddiesReady)
        players[p].eddiesReady -= fromEddies
        players[p].eddiesSpent += fromEddies
        remaining -= fromEddies
        while remaining > 0 {
            guard let slot = cheapestLegendToSpend(p) else { break }
            spendLegend(p, slot)
            remaining -= 1
        }
        return true
    }

    mutating func readyEddies(_ p: Int, _ count: Int) {
        let readied = min(count, players[p].eddiesSpent)
        players[p].eddiesSpent -= readied
        players[p].eddiesReady += readied
    }

    func cheapestLegendToSpend(_ p: Int) -> Int? {
        let candidates = players[p].legends.indices.filter { !players[p].legends[$0].spent }
        return candidates.min { legendSpendCost(p, $0) < legendSpendCost(p, $1) }
    }

    func legendSpendCost(_ p: Int, _ slot: Int) -> Int {
        let legend = players[p].legends[slot]
        if !legend.faceUp { return 0 }
        let gearBonus = legend.gears.contains { profile($0).hints.rewardsBeingSpent } ? -2 : 0
        return profile(legend.cardId).hints.manaReluctance + gearBonus
    }

    mutating func sellFromHand(_ p: Int, handIndex: Int) {
        let sold = removeFromHand(p, at: handIndex)
        players[p].eddiesReady += 1
        players[p].flags.sold = true
        note("P\(p) sells \(name(sold))")
    }
}
