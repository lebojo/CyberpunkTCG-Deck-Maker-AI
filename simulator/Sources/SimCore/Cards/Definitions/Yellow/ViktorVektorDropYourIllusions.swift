struct ViktorVektorDropYourIllusions: GameCard {
    let data: CardData
    let listens: EventMask = []
    var modifierScopes: ModifierScopes { .alliedPlayCost }

    func modifiers(in query: EffectQuery) -> CardModifiers {
        guard let played = query.subjectCardId, query.stats(played).kind == .gear, query.data(played).has(.cyberware) else { return .none }
        return .with {
            $0.costReduction = 3
            $0.costMinimum = 1
            $0.costOncePerTurnKey = query.onceKey()
        }
    }
}
