struct MaxTacSquadron: GameCard {
    let data: CardData
    let listens: EventMask = .endOfTurn

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .endOfTurn = event, context.selfUnit?.spent == true else { return }
        guard let slot = context.legends().indices.first(where: { context.legends()[$0].faceUp && context.legends()[$0].spent }) else { return }
        context.note("P\(context.owner) readies a Legend with \(context.card.name)")
        context.readyLegend(slot: slot)
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + (query.faceUpLegendCount() > 0 ? 3 : 0) }
    }
}
