struct SaburoArasakaStubbornPatriarch: GameCard {
    let data: CardData
    let listens: EventMask = []
    var modifierScopes: ModifierScopes { .alliedAttackers }
    var hints: AIHints { .with { $0.manaReluctance = 3 } }

    func modifiers(in query: EffectQuery) -> CardModifiers {
        guard let subject = query.subjectCardId, query.data(subject).has(.arasaka) else { return .none }
        return .with { $0.power = 1 }
    }
}
