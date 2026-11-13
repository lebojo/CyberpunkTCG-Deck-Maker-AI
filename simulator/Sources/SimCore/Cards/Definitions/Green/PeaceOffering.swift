struct PeaceOffering: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        context.setGigToMatchBest()
        if context.valuePairs() >= 1 { context.draw(1) }
    }

    func playValue(in query: EffectQuery) -> Double? {
        guard query.gigs().count >= 2 else { return nil }
        return query.bestMatchingGigSet() != nil ? 16 : nil
    }
}
