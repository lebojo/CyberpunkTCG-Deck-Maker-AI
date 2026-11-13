struct MoxInciters: GameCard {
    let data: CardData
    let listens: EventMask = .played

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .played = event, context.isAboutItself else { return }
        let rival = context.rival
        guard let target = context.bestRivalUnit(where: { !$0.spent && context.canAttack($0, owner: rival) }) else { return }
        context.forceAttackNextTurn(rival, uid: target.uid)
    }

    func playValue(in query: EffectQuery) -> Double? {
        let rival = query.rival
        let hasTarget = query.field(of: rival).contains { !$0.spent && query.canAttack($0, owner: rival) }
        return standardPlayValue(in: query).map { $0 + (hasTarget ? 5 : 0) }
    }
}
