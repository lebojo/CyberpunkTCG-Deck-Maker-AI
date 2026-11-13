struct DontFearTheReaper: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        spendAllRivalUnits(&context)
        defeatSpentUnit(&context)
    }

    private func spendAllRivalUnits(_ context: inout EffectContext) {
        let rival = context.rival
        for unit in context.field(of: rival) where !unit.spent {
            context.spendUnit(rival, uid: unit.uid)
        }
    }

    private func defeatSpentUnit(_ context: inout EffectContext) {
        if let target = context.bestRivalUnit(where: { $0.spent }) {
            context.defeat(context.rival, uid: target.uid)
            return
        }
        let owner = context.owner
        let ownSpent = context.field().filter { $0.spent }
        if let victim = ownSpent.min(by: { context.unitThreat($0, owner: owner) < context.unitThreat($1, owner: owner) }) {
            context.defeat(owner, uid: victim.uid)
        }
    }

    func playValue(in query: EffectQuery) -> Double? {
        let rival = query.rival
        guard let best = query.field(of: rival).map({ query.unitThreat($0, owner: rival) }).max() else { return nil }
        return 18 + best
    }
}
