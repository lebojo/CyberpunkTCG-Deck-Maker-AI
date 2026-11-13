struct CorporateSurveillance: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event, let target = context.bestRivalUnit(where: { isTarget($0, context) }) else { return }
        context.spendUnit(context.rival, uid: target.uid)
    }

    private func isTarget(_ unit: FieldUnit, _ reading: some GameReading) -> Bool {
        !unit.spent && reading.stats(unit.cardId).costValue <= 4
    }

    func playValue(in query: EffectQuery) -> Double? {
        query.field(of: query.rival).contains { isTarget($0, query) } ? 30 : nil
    }
}
