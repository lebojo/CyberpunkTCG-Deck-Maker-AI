struct ValentinoStreetRacer: GameCard {
    let data: CardData
    let listens: EventMask = .played

    static let maximumCost = 5

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .played = event, context.isAboutItself, let target = bestTarget(in: context) else { return }
        context.note("P\(context.owner) gives Adrenaline to \(context.data(target.cardId).name)")
        context.grantKeyword(.adrenaline, to: context.owner, uid: target.uid)
    }

    private func bestTarget(in reading: some GameReading) -> FieldUnit? {
        let owner = reading.owner
        return reading.field()
            .filter { $0.uid != reading.selfUid && reading.stats($0.cardId).costValue <= Self.maximumCost && $0.lagging && !$0.spent }
            .max { reading.unitThreat($0, owner: owner) < reading.unitThreat($1, owner: owner) }
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + (bestTarget(in: query) != nil ? 8 : 0) }
    }
}
