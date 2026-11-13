struct SatoriSwordOfSaburo: GameCard {
    let data: CardData
    let listens: EventMask = .wonFight
    var hints: AIHints { .with { $0.gearRemovalPriority = 5 } }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .wonFight = event, context.isAboutHost else { return }
        context.draw(1)
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + 3 }
    }

    func keepValue(in query: EffectQuery) -> Double {
        standardKeepValue(in: query) + 2
    }
}
