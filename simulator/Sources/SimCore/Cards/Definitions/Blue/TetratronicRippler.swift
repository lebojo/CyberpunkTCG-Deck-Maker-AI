struct TetratronicRippler: GameCard {
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
        guard case .becameSpent = event, context.isAboutHost, let top = context.takeTop(1).first else { return }
        if context.keepValue(top) < 11 {
            context.note("P\(context.owner) trashes \(context.data(top).name) from the top of the deck")
            context.putInTrash([top])
        } else {
            context.putOnTop([top])
        }
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + 1 }
    }
}
