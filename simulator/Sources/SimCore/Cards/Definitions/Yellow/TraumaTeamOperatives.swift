struct TraumaTeamOperatives: GameCard {
    let data: CardData
    let listens: EventMask = []
    var modifierScopes: ModifierScopes { .ownPlayCost }

    func modifiers(in query: EffectQuery) -> CardModifiers {
        let unitsInTrash = query.trash().filter { query.stats($0).kind == .unit }.count
        return .with {
            $0.costReduction = unitsInTrash
            $0.costMinimum = 1
        }
    }
}
