struct RitaWheelerNoStupidQuestions: GameCard {
    let data: CardData
    let listens: EventMask = .becameSpent

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .becameSpent = event, context.isAboutItself, let uid = context.selfUid else { return }
        let key = context.onceKey()
        guard !context.unitHasMark(context.owner, uid: uid, key: key) else { return }
        context.markUnit(context.owner, uid: uid, key: key)
        context.draw(1)
        context.discardWorst()
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + 3 }
    }
}
