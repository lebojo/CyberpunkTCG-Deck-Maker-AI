struct TygersWhisper: GameCard {
    let data: CardData
    let listens: EventMask = .played

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .played = event, context.isAboutItself, !context.hasCalledThisTurn,
              let slot = context.firstFaceDownLegend() else { return }
        context.callLegend(slot: slot, free: true)
    }

    func playValue(in query: EffectQuery) -> Double? {
        let canCall = !query.hasCalledThisTurn && query.legends().contains { !$0.faceUp }
        return standardPlayValue(in: query).map { $0 + (canCall ? 10 : 0) }
    }
}
