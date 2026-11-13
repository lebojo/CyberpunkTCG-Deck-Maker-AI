struct GoroTakemuraLosingHisWay: GameCard {
    let data: CardData
    let listens: EventMask = .attackDeclared

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .attackDeclared = event, context.isAboutItself, let uid = context.selfUid, context.allLegendsFaceUp() else { return }
        context.addPower(context.owner, uid: uid, 5)
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + (query.allLegendsFaceUp() ? 8 : 0) }
    }

    func keepValue(in query: EffectQuery) -> Double {
        standardKeepValue(in: query) + 4
    }
}
