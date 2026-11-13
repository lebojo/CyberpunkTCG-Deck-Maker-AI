struct AllIsLost: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        let milled = context.takeTop(3)
        let pick = milled.filter { context.stats($0).kind == .unit }.max { context.stats($0).costValue < context.stats($1).costValue }
        for id in milled {
            if id == pick { context.addToHand(id) } else { context.putInTrash([id]) }
        }
    }

    func playValue(in query: EffectQuery) -> Double? { 10 }
}
