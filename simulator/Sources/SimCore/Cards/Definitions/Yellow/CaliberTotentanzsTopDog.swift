struct CaliberTotentanzsTopDog: GameCard {
    let data: CardData
    let listens: EventMask = [.played, .defeated]

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard context.isAboutItself else { return }
        switch event {
        case .played:
            defeatCheapRivalUnit(&context)
        case .defeated:
            makeRivalDiscard(&context)
        default:
            break
        }
    }

    private func defeatCheapRivalUnit(_ context: inout EffectContext) {
        let rival = context.rival
        guard let target = context.bestRivalUnit(where: { context.stats($0.cardId).costValue <= 2 }) else { return }
        context.defeat(rival, uid: target.uid)
    }

    private func makeRivalDiscard(_ context: inout EffectContext) {
        let rival = context.rival
        guard let first = discardOne(&context, from: rival) else { return }
        let matchesGig = context.gigs().contains { $0.value == context.stats(first).costValue }
        if matchesGig { _ = discardOne(&context, from: rival) }
    }

    private func discardOne(_ context: inout EffectContext, from player: Int) -> Int? {
        guard !context.hand(of: player).isEmpty else { return nil }
        context.discardWorst(player)
        return context.trash(of: player).last
    }

    func playValue(in query: EffectQuery) -> Double? {
        let hasTarget = query.field(of: query.rival).contains { query.stats($0.cardId).costValue <= 2 }
        return standardPlayValue(in: query).map { $0 + (hasTarget ? 6 : 0) }
    }
}
