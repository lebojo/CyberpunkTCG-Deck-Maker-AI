struct MaelstromZealots: GameCard {
    let data: CardData
    let listens: EventMask = .lostFight

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .lostFight(let report) = event, context.isAboutItself else { return }
        context.defeatAfterFight(context.rival, uid: report.opponentUid)
    }

    func keepValue(in query: EffectQuery) -> Double {
        standardKeepValue(in: query) + 3
    }
}
