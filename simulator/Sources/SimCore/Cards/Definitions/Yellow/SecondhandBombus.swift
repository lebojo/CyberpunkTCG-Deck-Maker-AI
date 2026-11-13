struct SecondhandBombus: GameCard {
    let data: CardData
    let listens: EventMask = []
    var hints: AIHints { .with { $0.prefersNoGears = true } }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 - 6 }
    }

    func keepValue(in query: EffectQuery) -> Double {
        standardKeepValue(in: query) - 2
    }
}
