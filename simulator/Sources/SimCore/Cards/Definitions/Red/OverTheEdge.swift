struct OverTheEdge: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event, let limit = d20Value(context) else { return }
        let rival = context.rival
        if let target = context.bestRivalUnit(where: { context.power(of: $0, owner: rival) <= limit }) {
            context.defeat(rival, uid: target.uid)
        }
    }

    private func d20Value(_ reading: some GameReading) -> Int? {
        reading.gigs().first { $0.sides == 20 }?.value
    }

    func playValue(in query: EffectQuery) -> Double? {
        guard let limit = d20Value(query) else { return nil }
        let rival = query.rival
        return query.field(of: rival).contains { query.power(of: $0, owner: rival) <= limit } ? 34 : nil
    }
}
