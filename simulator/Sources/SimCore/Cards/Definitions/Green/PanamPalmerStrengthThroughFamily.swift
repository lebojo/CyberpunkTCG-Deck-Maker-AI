struct PanamPalmerStrengthThroughFamily: GameCard {
    let data: CardData
    let listens: EventMask = [.played, .turnStarted, .attackDeclared]

    func action(_ event: GameEvent, in context: inout EffectContext) {
        switch event {
        case .played where context.isAboutItself, .turnStarted:
            callLegendForFree(&context)
        case .attackDeclared where context.isAboutItself:
            discardToDrawPerLegend(&context)
        default:
            break
        }
    }

    private func callLegendForFree(_ context: inout EffectContext) {
        guard context.isMyTurn, !context.hasCalledThisTurn, let slot = context.firstFaceDownLegend() else { return }
        context.callLegend(slot: slot, free: true)
    }

    private func discardToDrawPerLegend(_ context: inout EffectContext) {
        guard !context.hand().isEmpty else { return }
        context.discardWorst()
        context.draw(context.faceUpLegendCount())
    }

    func playValue(in query: EffectQuery) -> Double? {
        let canCall = !query.hasCalledThisTurn && query.legends().contains { !$0.faceUp }
        return standardPlayValue(in: query).map { $0 + (canCall ? 6 : 0) }
    }

    func keepValue(in query: EffectQuery) -> Double {
        standardKeepValue(in: query) + 2
    }
}
