struct ElSombreronLaVenganzaLenta: GameCard {
    let data: CardData
    let listens: EventMask = .attackDeclared

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .attackDeclared(let uid, let target) = event, context.isAboutItself, let unit = context.selfUnit else { return }
        let bonus = maxGigValue(context)
        guard bonus > 0, context.availableMana >= 2, isWorthPaying(bonus, unit: unit, target: target, context) else { return }
        guard context.payEddies(2) else { return }
        context.addPower(context.owner, uid: uid, bonus)
        context.note("P\(context.owner) pays 2 for +\(bonus) power")
    }

    private func maxGigValue(_ reading: some GameReading) -> Int {
        reading.gigs().filter(\.isMax).map(\.value).max() ?? 0
    }

    private func isWorthPaying(_ bonus: Int, unit: FieldUnit, target: AttackTarget, _ reading: some GameReading) -> Bool {
        let rival = reading.rival
        let current = reading.power(of: unit, owner: reading.owner, attacking: true)
        let boosted = current + bonus
        switch target {
        case .gigs:
            let blockers = reading.field(of: rival).filter { !$0.spent && reading.isBlocker($0, owner: rival) }
            let beatsBlocker = blockers.contains { reading.power(of: $0, owner: rival) >= current && reading.power(of: $0, owner: rival) < boosted }
            return reading.stealCount(forPower: boosted) > reading.stealCount(forPower: current) || beatsBlocker
        case .unit(let defenderUid):
            guard let defender = reading.unit(rival, defenderUid) else { return false }
            let defense = reading.power(of: defender, owner: rival)
            return current <= defense && boosted > defense
        }
    }

    func attackValueBonus(in query: EffectQuery) -> Double {
        query.gigs().contains(where: \.isMax) && query.availableMana >= 2 ? 4 : 0
    }
}
