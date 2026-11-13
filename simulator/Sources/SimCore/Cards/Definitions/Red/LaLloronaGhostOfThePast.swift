struct LaLloronaGhostOfThePast: GameCard {
    let data: CardData
    let listens: EventMask = .blocked

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .blocked = event, context.isAboutItself else { return }
        context.increaseGigBest(by: 3)
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + 2 }
    }
}
