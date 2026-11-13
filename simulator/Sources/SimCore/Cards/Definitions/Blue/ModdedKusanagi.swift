struct ModdedKusanagi: GameCard {
    let data: CardData
    let listens: EventMask = .endOfTurn

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .endOfTurn = event, let uid = context.selfUid else { return }
        context.returnUnitToHand(context.owner, uid: uid)
    }

    func playValue(in query: EffectQuery) -> Double? {
        let rivalHasGigs = !query.gigs(of: query.rival).isEmpty
        return standardPlayValue(in: query).map { $0 + (rivalHasGigs ? 6 : -10) }
    }
}
