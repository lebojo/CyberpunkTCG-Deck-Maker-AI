struct SandayuOdaHanakosGuardian: GameCard {
    let data: CardData
    let listens: EventMask = .played

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .played = event, context.isAboutItself else { return }
        for _ in 0..<context.valuePairs() {
            if let target = context.bestRivalUnit(where: { !$0.spent }) { context.spendUnit(context.rival, uid: target.uid) }
        }
    }

    func playValue(in query: EffectQuery) -> Double? {
        let useful = query.valuePairs() >= 1 && query.field(of: query.rival).contains { !$0.spent }
        return standardPlayValue(in: query).map { $0 + (useful ? 12 : 0) }
    }
}
