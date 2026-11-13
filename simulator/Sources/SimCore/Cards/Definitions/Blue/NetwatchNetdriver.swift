struct NetwatchNetdriver: GameCard {
    let data: CardData
    let listens: EventMask = .becameSpent

    var hints: AIHints {
        .with {
            $0.rewardsBeingSpent = true
            $0.suitsFaceUpLegend = true
            $0.gearRemovalPriority = 3
        }
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .becameSpent = event, context.isAboutHost else { return }
        context.draw(1)
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + 3 }
    }
}
