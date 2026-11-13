struct MemoryRelapse: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        let rival = context.rival
        if let target = context.bestRivalUnit(where: { !$0.spent }) ?? context.bestRivalUnit() {
            context.spendUnit(rival, uid: target.uid)
            context.forbidReadyUntilYourNextTurn(rival, uid: target.uid)
        }
        if let streetCred = context.streetCred(), streetCred % 2 == 0 { context.draw(1) }
    }

    func playValue(in query: EffectQuery) -> Double? {
        let rival = query.rival
        guard !query.field(of: rival).isEmpty else { return nil }
        let hasReadyTarget = query.field(of: rival).contains { !$0.spent }
        let evenBonus: Double = (query.streetCred() ?? 1) % 2 == 0 ? 4 : 0
        return (hasReadyTarget ? 20 : 8) + evenBonus
    }
}
