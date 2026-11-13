struct LiveWithTheAftermath: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        defeatWeakestUnit(&context, of: context.owner)
        defeatWeakestUnit(&context, of: context.rival)
    }

    private func defeatWeakestUnit(_ context: inout EffectContext, of player: Int) {
        guard let unit = context.weakestUnit(of: player) else { return }
        context.defeat(player, uid: unit.uid)
    }

    func playValue(in query: EffectQuery) -> Double? {
        guard let theirs = query.weakestUnit(of: query.rival) else { return nil }
        let ownLoss = query.weakestUnit(of: query.owner).map { query.unitThreat($0, owner: query.owner) } ?? 0
        let value = 4 + query.unitThreat(theirs, owner: query.rival) - ownLoss
        return value < 5 ? nil : value
    }

    func keepValue(in query: EffectQuery) -> Double { 6 }
}
