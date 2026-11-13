struct AppetiteForDestruction: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        switch event {
        case .programResolves:
            context.registerDelayed(.wonFight, expiry: .endOfTurn)
        case .wonFight(let report) where context.isDelayedTrigger:
            guard report.power - report.opponentPower >= 3 else { return }
            context.consumeDelayedTrigger()
            stealExtraGig(after: report, &context)
        default:
            break
        }
    }

    private func stealExtraGig(after report: FightReport, _ context: inout EffectContext) {
        guard context.unit(context.owner, report.unitUid) != nil else { return }
        let owner = context.owner
        let candidates = context.gigs(of: context.rival)
        context.stealExtraGig(attackerUid: report.unitUid) { game in
            candidates.max { game.gigStealPriority(owner, $0) < game.gigStealPriority(owner, $1) }
        }
    }

    func playValue(in query: EffectQuery) -> Double? {
        let owner = query.owner
        let rival = query.rival
        guard !query.gigs(of: rival).isEmpty else { return nil }
        let attackers = query.field().filter { query.canAttack($0, owner: owner) }
        let targets = query.field(of: rival).filter { $0.spent }
        let canWinBig = attackers.contains { attacker in
            targets.contains { query.power(of: attacker, owner: owner, attacking: true) - query.power(of: $0, owner: rival) >= 3 }
        }
        return canWinBig ? 14 : nil
    }
}
