struct MantisBlades: GameCard {
    let data: CardData
    let listens: EventMask = []
    var hints: AIHints { .with { $0.gearRemovalPriority = 3 } }

    func keepValue(in query: EffectQuery) -> Double {
        standardKeepValue(in: query) + 2
    }
}
