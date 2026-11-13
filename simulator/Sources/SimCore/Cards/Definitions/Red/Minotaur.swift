struct Minotaur: GameCard {
    let data: CardData
    let listens: EventMask = .played

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .played = event, context.isAboutItself, context.hasMoreStreetCred else { return }
        let rival = context.rival
        if let target = context.bestRivalUnit(where: { context.power(of: $0, owner: rival) <= 5 }) {
            context.defeat(rival, uid: target.uid)
        }
    }

    func playValue(in query: EffectQuery) -> Double? {
        let rival = query.rival
        let hasTarget = query.hasMoreStreetCred && query.field(of: rival).contains { query.power(of: $0, owner: rival) <= 5 }
        return standardPlayValue(in: query).map { $0 + (hasTarget ? 12 : 0) }
    }

    func keepValue(in query: EffectQuery) -> Double {
        standardKeepValue(in: query) + 4
    }
}
