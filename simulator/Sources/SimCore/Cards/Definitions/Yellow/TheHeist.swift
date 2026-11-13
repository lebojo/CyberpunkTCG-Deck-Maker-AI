struct TheHeist: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        let milled = context.takeTop(4)
        let gear = milled.filter { context.stats($0).kind == .gear }.max { context.stats($0).power < context.stats($1).power }
        context.putInTrash(milled.filter { $0 != gear })
        guard let gear else { return }
        let playsFree = context.gigs().contains { $0.value == context.stats(gear).costValue }
        context.addToHand(gear, revealed: false)
        if playsFree { context.playFromHand(gear, free: true, newestCopy: true) }
    }

    func playValue(in query: EffectQuery) -> Double? { 18 }
}
