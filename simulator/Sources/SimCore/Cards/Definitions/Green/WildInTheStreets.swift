struct WildInTheStreets: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event, let target = context.bestRivalUnit(where: { $0.spent }) else { return }
        context.defeat(context.rival, uid: target.uid)
    }

    func playValue(in query: EffectQuery) -> Double? {
        query.field(of: query.rival).contains { $0.spent } ? 34 : nil
    }
}
