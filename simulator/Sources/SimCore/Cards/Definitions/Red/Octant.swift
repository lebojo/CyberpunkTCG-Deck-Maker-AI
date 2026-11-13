struct Octant: GameCard {
    let data: CardData
    let listens: EventMask = []
    var modifierScopes: ModifierScopes { .ownPlayCost }

    func modifiers(in query: EffectQuery) -> CardModifiers {
        .with { $0.costReduction = query.friendlyGigsWith8PlusValue }
    }
}
