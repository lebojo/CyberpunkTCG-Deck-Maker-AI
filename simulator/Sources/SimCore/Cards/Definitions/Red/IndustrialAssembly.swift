struct IndustrialAssembly: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        context.increaseGigBest(by: 4)
        if context.hasGig(atLeast: 8) { context.draw(1) }
    }

    func playValue(in query: EffectQuery) -> Double? {
        guard !query.gigs().isEmpty else { return nil }
        return query.bestGigAdjustment(up: 4, down: 0) != nil ? 14 : nil
    }
}
