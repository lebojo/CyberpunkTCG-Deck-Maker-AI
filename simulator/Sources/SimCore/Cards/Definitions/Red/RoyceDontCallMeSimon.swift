struct RoyceDontCallMeSimon: GameCard {
    let data: CardData
    let listens: EventMask = .played

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .played = event, context.isAboutItself else { return }
        let rival = context.rival
        let limit = powerLimit(context)
        if let target = context.bestRivalUnit(where: { context.power(of: $0, owner: rival) <= limit }) {
            context.defeat(rival, uid: target.uid)
        }
    }

    private func powerLimit(_ reading: some GameReading) -> Int {
        reading.hasMoreStreetCred ? 3 : 2
    }

    func playValue(in query: EffectQuery) -> Double? {
        let rival = query.rival
        let limit = powerLimit(query)
        let hasTarget = query.field(of: rival).contains { query.power(of: $0, owner: rival) <= limit }
        return standardPlayValue(in: query).map { $0 + (hasTarget ? 12 : 0) }
    }

    func keepValue(in query: EffectQuery) -> Double {
        standardKeepValue(in: query) + 3
    }
}
