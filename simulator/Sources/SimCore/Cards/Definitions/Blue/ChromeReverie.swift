struct ChromeReverie: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        if let target = context.bestRivalUnit() {
            context.forbidAttackUntilYourNextTurn(context.rival, uid: target.uid)
        }
        if context.minGigCount() >= 1, !context.hasCalledThisTurn, let slot = context.firstFaceDownLegend() {
            context.callLegend(slot: slot, free: true)
        }
    }

    func playValue(in query: EffectQuery) -> Double? {
        let rival = query.rival
        guard query.field(of: rival).contains(where: { !$0.spent && query.power(of: $0, owner: rival, attacking: true) > 0 }) else { return nil }
        return 26 + (query.minGigCount() >= 1 && !query.hasCalledThisTurn ? 8 : 0)
    }
}
