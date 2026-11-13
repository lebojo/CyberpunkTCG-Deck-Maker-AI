struct MaelstromGoons: GameCard {
    let data: CardData
    let listens: EventMask = .stoleGigs

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .stoleGigs = event, context.isAboutItself else { return }
        guard context.selfUnit?.isEquipped == true, !context.hand(of: context.rival).isEmpty else { return }
        context.discardWorst(context.rival)
    }

    func attackValueBonus(in query: EffectQuery) -> Double {
        query.selfUnit?.isEquipped == true ? 5 : 0
    }
}
