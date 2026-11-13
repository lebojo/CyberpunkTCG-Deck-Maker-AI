struct LesElemens: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event, let target = context.worstRivalUnit() else { return }
        context.bottomDeckUnit(context.rival, uid: target.uid)
    }

    func playValue(in query: EffectQuery) -> Double? {
        guard let weakest = query.worstRivalUnit() else { return nil }
        return query.stats(weakest.cardId).costValue >= 3 ? 20 : 10
    }
}
