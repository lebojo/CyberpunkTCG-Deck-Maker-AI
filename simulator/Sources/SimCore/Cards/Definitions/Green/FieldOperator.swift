struct FieldOperator: GameCard {
    let data: CardData
    let listens: EventMask = .played

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .played = event, context.isAboutItself, let streetCred = context.streetCred(), streetCred % 2 == 0 else { return }
        context.draw(1)
    }
}
