struct ChromeFang: GameCard {
    let data: CardData
    let listens: EventMask = .played

    func action(_ event: GameEvent, in context: inout EffectContext) {
        switch event {
        case .played where context.isAboutItself:
            context.registerDelayed(.gigWouldBeStolen, expiry: .untilYourNextTurn)
        case .gigWouldBeStolen(let gig, let attackerUid) where context.isDelayedTrigger:
            guard let attacker = context.unit(context.rival, attackerUid),
                  gig.value > context.power(of: attacker, owner: context.rival, attacking: true) else { return }
            context.prevent()
        default:
            break
        }
    }

    func playValue(in query: EffectQuery) -> Double? {
        let hasThreats = !query.field(of: query.rival).isEmpty && !query.gigs().isEmpty
        return standardPlayValue(in: query).map { $0 + (hasThreats ? 4 : 0) }
    }
}
