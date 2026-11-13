struct Sandevistan: GameCard {
    let data: CardData
    let listens: EventMask = .endOfTurn

    var hints: AIHints {
        .with {
            $0.gearRemovalPriority = 6
            $0.suitsFaceUpLegend = true
            $0.ignoresExposure = true
        }
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .endOfTurn = event, context.isAboutHost else { return }
        context.readyHost()
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + 3 }
    }

    func keepValue(in query: EffectQuery) -> Double {
        standardKeepValue(in: query) + 2
    }
}
