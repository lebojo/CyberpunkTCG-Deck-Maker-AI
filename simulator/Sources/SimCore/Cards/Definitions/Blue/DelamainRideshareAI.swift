struct DelamainRideshareAI: GameCard {
    let data: CardData
    let listens: EventMask = .played

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .played = event, context.isAboutItself else { return }
        context.draw(2)
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + 7 }
    }

    func keepValue(in query: EffectQuery) -> Double {
        standardKeepValue(in: query) + 4
    }
}
