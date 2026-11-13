struct KiroshiOptics: GameCard {
    let data: CardData
    let listens: EventMask = []
    var hints: AIHints { .with { $0.gearRemovalPriority = 1 } }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 - 3 }
    }

    func keepValue(in query: EffectQuery) -> Double {
        standardKeepValue(in: query) - 2
    }
}
