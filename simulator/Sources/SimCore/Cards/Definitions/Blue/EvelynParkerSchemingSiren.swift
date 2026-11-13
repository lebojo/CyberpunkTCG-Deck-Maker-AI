struct EvelynParkerSchemingSiren: GameCard {
    let data: CardData
    let listens: EventMask = .attackDeclared
    var hints: AIHints { .with { $0.attackWithoutStealValue = 8 } }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .attackDeclared = event, context.isAboutItself else { return }
        context.draw(1)
        if context.hasMoreStreetCred { context.discardWorst() }
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + 4 }
    }
}
