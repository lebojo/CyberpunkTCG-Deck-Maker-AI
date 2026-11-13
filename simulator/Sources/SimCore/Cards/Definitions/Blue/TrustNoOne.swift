struct TrustNoOne: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        context.decreaseGigBest(by: 3)
        if context.minGigCount() >= 1 { context.draw(1) }
    }

    func playValue(in query: EffectQuery) -> Double? {
        guard !query.gigs().isEmpty else { return nil }
        if query.bestGigAdjustment(up: 0, down: 3) != nil { return query.wantsMinGigs ? 22 : 9 }
        return query.minGigCount() >= 1 ? 9 : nil
    }
}
