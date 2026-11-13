struct ThreeMouthsOneDesire: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        let top = context.takeTop(3)
        let take = min(top.count, 1 + context.minGigCount())
        let ranked = top.sorted { context.keepValue($0) > context.keepValue($1) }
        for id in ranked.prefix(take) { context.addToHand(id, revealed: false) }
        context.bottomDeck(Array(ranked.dropFirst(take)))
    }

    func playValue(in query: EffectQuery) -> Double? { 24 }
}
