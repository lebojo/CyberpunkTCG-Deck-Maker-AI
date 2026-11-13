struct LucynaKushinadaFreshBeginnings: GameCard {
    let data: CardData
    let listens: EventMask = .calledAsLegend

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .calledAsLegend = event, context.isAboutItself else { return }
        context.draw(context.minGigCount() >= 2 ? 2 : 1)
    }
}
