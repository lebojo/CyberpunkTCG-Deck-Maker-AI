struct MandibularUpgrade: GameCard {
    let data: CardData
    let listens: EventMask = []

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + 4 }
    }

    func keepValue(in query: EffectQuery) -> Double {
        standardKeepValue(in: query) - 2
    }
}
