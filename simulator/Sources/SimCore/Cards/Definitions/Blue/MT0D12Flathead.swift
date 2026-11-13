struct MT0D12Flathead: GameCard {
    let data: CardData
    let listens: EventMask = []
    var modifierScopes: ModifierScopes { .itself }

    func modifiers(in query: EffectQuery) -> CardModifiers {
        guard query.subjectIsSelf, query.hasLessStreetCred else { return .none }
        return .with { $0.keywords = .unblockable }
    }
}
