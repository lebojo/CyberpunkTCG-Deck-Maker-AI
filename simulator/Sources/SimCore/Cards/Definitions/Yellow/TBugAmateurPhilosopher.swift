struct TBugAmateurPhilosopher: GameCard {
    let data: CardData
    let listens: EventMask = .defeated

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .defeated = event, context.isAboutItself else { return }
        guard !context.hasCalledThisTurn || !context.isMyTurn else { return }
        guard let slot = bestSlotToCall(context) else { return }
        context.callLegend(slot: slot, free: true)
    }

    private func bestSlotToCall(_ context: EffectContext) -> Int? {
        let legends = context.legends()
        let slots = legends.indices.filter { !legends[$0].faceUp }
        if slots.count == 1 { return slots.first }
        return slots.max { score(ofCalling: $0, in: context) < score(ofCalling: $1, in: context) }
    }

    private func score(ofCalling slot: Int, in context: EffectContext) -> Double {
        var trial = context
        trial.callLegend(slot: slot, free: true)
        return trial.game.evaluate(context.owner)
    }

    func keepValue(in query: EffectQuery) -> Double {
        standardKeepValue(in: query) + (query.legends().contains { !$0.faceUp } ? 2 : 0)
    }
}
