struct JapantownJonin: GameCard {
    let data: CardData
    let listens: EventMask = .played

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .played = event, context.isAboutItself, let target = target(context) else { return }
        context.addPower(context.owner, uid: target.uid, 2)
    }

    private func target(_ reading: some GameReading) -> FieldUnit? {
        let owner = reading.owner
        return reading.bestAllyUnit { reading.canAttack($0, owner: owner) } ?? reading.bestAllyUnit()
    }

    func playValue(in query: EffectQuery) -> Double? {
        let owner = query.owner
        let hasAttacker = query.field().contains { query.canAttack($0, owner: owner) }
        return standardPlayValue(in: query).map { $0 + (hasAttacker ? 4 : 0) }
    }
}
