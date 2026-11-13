struct PyramidSong: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        let rival = context.rival
        if choosesBoth(context), let target = context.bestRivalUnit(where: { context.power(of: $0, owner: rival) <= 4 }) {
            context.addPower(rival, uid: target.uid, -4)
            context.bottomDeckUnit(rival, uid: target.uid)
            return
        }
        if let target = context.bestRivalUnit(where: { context.power(of: $0, owner: rival) == 0 }) {
            context.bottomDeckUnit(rival, uid: target.uid)
        }
    }

    private func choosesBoth(_ reading: some GameReading) -> Bool {
        reading.gigs().contains { $0.sides == 4 && $0.isMin }
    }

    func playValue(in query: EffectQuery) -> Double? {
        let rival = query.rival
        if choosesBoth(query), query.field(of: rival).contains(where: { query.power(of: $0, owner: rival) <= 4 }) { return 36 }
        return query.field(of: rival).contains(where: { query.power(of: $0, owner: rival) == 0 }) ? 24 : nil
    }
}
