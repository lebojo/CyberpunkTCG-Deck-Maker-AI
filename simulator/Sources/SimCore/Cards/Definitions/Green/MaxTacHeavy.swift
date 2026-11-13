struct MaxTacHeavy: GameCard {
    let data: CardData
    let listens: EventMask = []
    var modifierScopes: ModifierScopes { .ownPlayCost }

    func modifiers(in query: EffectQuery) -> CardModifiers {
        .with {
            $0.costReduction = query.field(of: query.rival).count
            $0.costMinimum = 1
        }
    }
}
