struct AdrenalineConverter: GameCard {
    let data: CardData
    let listens: EventMask = []
    var modifierScopes: ModifierScopes { .equippedUnit }

    func modifiers(in query: EffectQuery) -> CardModifiers {
        guard query.gigs(of: query.rival).count >= query.gigs().count + 2 else { return .none }
        return .with { $0.keywords = .adrenaline }
    }
}
