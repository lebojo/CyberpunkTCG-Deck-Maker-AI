struct OffdutyMalfini: GameCard {
    let data: CardData
    let listens: EventMask = .played

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .played = event, context.isAboutItself, let uid = context.selfUid else { return }
        context.spendUnit(context.owner, uid: uid)
        if let target = context.bestRivalUnit(where: { !$0.spent }) {
            context.spendUnit(context.rival, uid: target.uid)
        }
    }

    func playValue(in query: EffectQuery) -> Double? {
        let rivalHasReadyUnit = query.field(of: query.rival).contains { !$0.spent }
        return standardPlayValue(in: query).map { $0 + (rivalHasReadyUnit ? 12 : -14) }
    }
}
