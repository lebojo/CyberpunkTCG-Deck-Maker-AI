struct ZetatechFaceplate: GameCard {
    let data: CardData
    let listens: EventMask = .becameSpent

    var hints: AIHints {
        .with {
            $0.rewardsBeingSpent = true
            $0.suitsFaceUpLegend = true
            $0.gearRemovalPriority = 4
        }
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .becameSpent = event, context.isAboutHost else { return }
        context.adjustGigBest(by: 1)
        if context.distinctGigValues() >= 3 && context.gigs().count >= 3 { context.draw(1) }
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + 3 }
    }
}
