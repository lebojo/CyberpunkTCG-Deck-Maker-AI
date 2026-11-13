struct AfterpartyAtLizzies: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        if let choice = context.bestGigAdjustment(up: 1, down: 1) {
            context.setGig(context.owner, index: choice.index, to: choice.value)
        }
        if hasDistinctPair(context) { context.draw(1) }
    }

    func playValue(in query: EffectQuery) -> Double? {
        if hasDistinctPair(query) { return 14 }
        return query.bestGigAdjustment(up: 1, down: 1) != nil ? 8 : nil
    }

    private func hasDistinctPair(_ reading: some GameReading) -> Bool {
        reading.gigs().count >= 2 && reading.distinctGigValues() >= 2
    }
}
