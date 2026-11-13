struct CarnageAtTheColosseum: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves
    var modifierScopes: ModifierScopes { .ownPlayCost }

    func modifiers(in query: EffectQuery) -> CardModifiers {
        .with { $0.costReduction = query.friendlyGigsWith8PlusValue }
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event, let target = target(context) else { return }
        context.defeat(context.rival, uid: target.uid)
    }

    private func target(_ reading: some GameReading) -> FieldUnit? {
        let owner = reading.owner
        let rival = reading.rival
        guard let strongest = reading.field().map({ reading.power(of: $0, owner: owner) }).max() else { return nil }
        return reading.bestRivalUnit { reading.power(of: $0, owner: rival) < strongest }
    }

    func playValue(in query: EffectQuery) -> Double? {
        target(query) != nil ? 30 : nil
    }
}
