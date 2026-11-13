enum QuickOdds {
    static func atLeastOne(poolSize: Int, quickCount: Int, handSize: Int) -> Double {
        guard quickCount > 0, handSize > 0, poolSize > 0 else { return 0 }
        let others = poolSize - quickCount
        guard handSize <= others else { return 1 }
        var none = 1.0
        for drawn in 0..<handSize {
            none *= Double(others - drawn) / Double(poolSize - drawn)
        }
        return 1 - none
    }
}

extension Game {
    static let swingWindow = 3

    func isQuick(_ id: Int) -> Bool {
        let timings = profile(id).abilityTimings
        return timings.contains(.fight) || timings.contains(.rivalAttacksGigs)
    }

    func quickCost(_ id: Int) -> Int {
        let abilityCost = catalog.abilities[id].filter { $0.timing == .fight || $0.timing == .rivalAttacksGigs }.map(\.eddieCost).min() ?? 0
        return max(abilityCost, stats(id).costValue)
    }

    func unseenCards(of q: Int) -> [Int] {
        var hidden = players[q].hand
        for id in knownHandCards(of: q) {
            if let position = hidden.firstIndex(of: id) { hidden.remove(at: position) }
        }
        return hidden + players[q].deck
    }

    func quickThreat(of q: Int) -> Double {
        let open = availableMana(q)
        let affordable = { (id: Int) in isQuick(id) && quickCost(id) <= open }
        if knownHandCards(of: q).contains(where: affordable) { return 1 }
        let pool = unseenCards(of: q)
        let hiddenHand = players[q].hand.count - knownHandCards(of: q).count
        return QuickOdds.atLeastOne(poolSize: pool.count, quickCount: pool.filter(affordable).count, handSize: hiddenHand)
    }

    func cheapestQuickInDeckList(of p: Int) -> Int? {
        (players[p].hand + players[p].deck).filter(isQuick).map(quickCost).min()
    }

    func quickDeterrence(attacker p: Int, unit: FieldUnit, target: AttackTarget, threat: Double) -> Double {
        guard threat > 0 else { return 0 }
        let rival = 1 - p
        let myPower = power(p, unit, attacking: true)
        let unitValue = unitThreat(p, unit)
        switch target {
        case .unit(let uid):
            guard let defender = self.unit(rival, uid) else { return 0 }
            let margin = myPower - power(rival, defender, attacking: false)
            return margin <= Game.swingWindow ? threat * unitValue * 0.9 : 0
        case .gigs:
            guard !isUnblockable(unit, owner: p) else { return threat * 4 }
            let closeBlock = players[rival].field.contains {
                !$0.spent && isBlocker(rival, $0) && myPower - power(rival, $0, attacking: false) <= Game.swingWindow
            }
            return closeBlock ? threat * unitValue * 0.6 : threat * 4
        }
    }
}
