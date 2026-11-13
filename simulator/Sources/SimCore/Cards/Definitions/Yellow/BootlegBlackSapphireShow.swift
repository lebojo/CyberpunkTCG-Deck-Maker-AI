struct BootlegBlackSapphireShow: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        context.sellTopOfDeck()
        if context.hasEvenAndOddGig() { context.draw(2) }
    }

    func playValue(in query: EffectQuery) -> Double? {
        query.hasEvenAndOddGig() ? 22 : 10
    }
}
