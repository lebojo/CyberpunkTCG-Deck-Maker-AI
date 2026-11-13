struct IncomingAttacker: Sendable, Hashable {
    var power: Int
    var weight: Double
    var unblockable: Bool
}

struct GuardContext: Sendable {
    var incoming: [IncomingAttacker]
    var fullDefense: Double
}

enum DefenseValue {
    static func of(blockers: [Int], attackers: [IncomingAttacker], attackWorth: (Int) -> Double) -> Double {
        var available = blockers.sorted()
        var value = 0.0
        let ordered = attackers.filter { !$0.unblockable }.sorted { ($0.power, $0.weight) > ($1.power, $1.weight) }
        for attacker in ordered {
            guard let index = available.firstIndex(where: { $0 >= attacker.power }) else { continue }
            available.remove(at: index)
            value += attacker.weight * attackWorth(attacker.power)
        }
        return value
    }
}

extension Game {
    static let defenseWeight = 0.5
    static let boardDefenseWeight = 0.1
    static let guardWeight = 0.3

    func stealSwing(defender d: Int, steals: Int) -> Double {
        let mine = players[d].gigs.count
        let theirs = players[1 - d].gigs.count
        let taken = min(steals, mine)
        let swing = gigValue(theirs + taken) - gigValue(theirs) + gigValue(mine) - gigValue(mine - taken)
        return Game.defenseWeight * swing
    }

    func readyBlockerPowers(_ d: Int, excluding uid: Int? = nil) -> [Int] {
        players[d].field.filter { !$0.spent && $0.uid != uid && isBlocker(d, $0) }.map { power(d, $0, attacking: false) }
    }

    func incomingAttackers(against d: Int) -> [IncomingAttacker] {
        let rival = 1 - d
        let nextTurn = turn + 1
        var result = players[rival].field.filter { unit in
            !keywords(rival, unit).contains(.cannotAttack) && !keywords(rival, unit).contains(.cannotStealGigs)
                && unit.cannotReadyBefore <= nextTurn && unit.cannotAttackBefore <= nextTurn
        }.map { IncomingAttacker(power: power(rival, $0, attacking: true), weight: 1, unblockable: isUnblockable($0, owner: rival)) }
        result.append(contentsOf: rushThreats(from: rival))
        return result
    }

    func rushThreats(from q: Int) -> [IncomingAttacker] {
        let mana = players[q].eddiesReady + players[q].eddiesSpent + players[q].legends.count
        let rushes = { (id: Int) in
            stats(id).kind == .unit && stats(id).costValue <= mana
                && (profile(id).keywords.contains(.adrenaline) || profile(id).keywords.contains(.attacksGigsWhenPlayed))
        }
        let known = knownHandCards(of: q).filter(rushes)
        if let best = known.max(by: { stats($0).power < stats($1).power }) {
            return [IncomingAttacker(power: stats(best).power, weight: 1, unblockable: profile(best).keywords.contains(.unblockable))]
        }
        let pool = unseenCards(of: q)
        let hidden = players[q].hand.count - knownHandCards(of: q).count + 1
        let candidates = pool.filter(rushes)
        guard let best = candidates.max(by: { stats($0).power < stats($1).power }) else { return [] }
        let odds = QuickOdds.atLeastOne(poolSize: pool.count, quickCount: candidates.count, handSize: hidden)
        return [IncomingAttacker(power: stats(best).power, weight: odds, unblockable: profile(best).keywords.contains(.unblockable))]
    }

    func defenseValue(_ d: Int, excluding uid: Int? = nil) -> Double {
        guard !players[d].gigs.isEmpty else { return 0 }
        return defenseValue(d, excluding: uid, against: incomingAttackers(against: d))
    }

    func defenseValue(_ d: Int, excluding uid: Int?, against incoming: [IncomingAttacker]) -> Double {
        guard !players[d].gigs.isEmpty else { return 0 }
        return DefenseValue.of(blockers: readyBlockerPowers(d, excluding: uid), attackers: incoming, attackWorth: { stealSwing(defender: d, steals: stealCount(forPower: $0)) })
    }

    func guardContext(_ p: Int, attackers: [FieldUnit]) -> GuardContext? {
        guard !players[p].gigs.isEmpty, attackers.contains(where: { isBlocker(p, $0) }) else { return nil }
        let incoming = incomingAttackers(against: p)
        return GuardContext(incoming: incoming, fullDefense: defenseValue(p, excluding: nil, against: incoming))
    }

    func guardCost(_ p: Int, _ unit: FieldUnit) -> Double {
        guardCost(p, unit, context: guardContext(p, attackers: [unit]))
    }

    func guardCost(_ p: Int, _ unit: FieldUnit, context: GuardContext?) -> Double {
        guard let context, isBlocker(p, unit) else { return 0 }
        return Game.guardWeight * (context.fullDefense - defenseValue(p, excluding: unit.uid, against: context.incoming))
    }

    func defenseBalance(_ me: Int) -> Double {
        Game.boardDefenseWeight * (active == me ? -defenseValue(1 - me) : defenseValue(me))
    }
}
