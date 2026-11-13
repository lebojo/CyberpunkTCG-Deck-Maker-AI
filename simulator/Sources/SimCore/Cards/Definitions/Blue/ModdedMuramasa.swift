struct ModdedMuramasa: GameCard {
    let data: CardData
    let listens: EventMask = .endOfTurn

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .endOfTurn = event, let uid = context.selfUid, context.hasLessStreetCred else { return }
        context.readyUnit(context.owner, uid: uid)
    }

    func attackValueBonus(in query: EffectQuery) -> Double {
        query.hasLessStreetCred ? 5 : 0
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + (query.hasLessStreetCred ? 4 : 0) }
    }
}
