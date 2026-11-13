struct ArasakaEmergencyRadioport: GameCard {
    let data: CardData
    let listens: EventMask = .becameSpent

    var hints: AIHints {
        .with {
            $0.rewardsBeingSpent = true
            $0.suitsFaceUpLegend = true
        }
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .becameSpent = event, context.isAboutHost, !context.hasCalledThisTurn else { return }
        guard let slot = context.firstFaceDownLegend(where: { $0.has(.arasaka) || $0.hasGoSolo }) else { return }
        context.callLegend(slot: slot, free: true)
    }
}
