struct UnlikelyBond: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event, let ally = sacrifice(context) else { return }
        let rival = context.rival
        let target = context.bestRivalUnit(where: { $0.spent })
        context.bottomDeckUnit(context.owner, uid: ally.uid)
        if let target { context.bottomDeckUnit(rival, uid: target.uid) }
    }

    private func sacrifice(_ reading: some GameReading) -> FieldUnit? {
        reading.field().filter { !$0.spent }.min { reading.unitThreat($0, owner: reading.owner) < reading.unitThreat($1, owner: reading.owner) }
    }

    func playValue(in query: EffectQuery) -> Double? {
        guard let ally = sacrifice(query), let target = query.bestRivalUnit(where: { $0.spent }) else { return nil }
        let gain = query.unitThreat(target, owner: query.rival) - query.unitThreat(ally, owner: query.owner)
        return gain > 4 ? 12 + gain : nil
    }

    func keepValue(in query: EffectQuery) -> Double { 8 }
}
