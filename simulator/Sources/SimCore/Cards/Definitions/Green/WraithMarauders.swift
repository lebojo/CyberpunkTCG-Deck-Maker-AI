struct WraithMarauders: GameCard {
    let data: CardData
    let listens: EventMask = .gigStolen

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .gigStolen(let gig, _) = event, context.isAboutItself else { return }
        let owner = context.owner
        let candidates = context.field().filter { $0.spent && $0.uid != context.selfUid && context.power(of: $0, owner: owner) == gig.value }
        guard let target = candidates.max(by: { context.unitThreat($0, owner: owner) < context.unitThreat($1, owner: owner) }) else { return }
        context.note("P\(owner) readies \(context.data(target.cardId).name) with power \(gig.value)")
        context.readyUnit(owner, uid: target.uid)
    }
}
