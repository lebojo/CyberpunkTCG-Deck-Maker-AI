struct WestbrookNetrunner: GameCard {
    let data: CardData
    let listens: EventMask = .played

    func action(_ event: GameEvent, in context: inout EffectContext) {
        switch event {
        case .played where context.isAboutItself:
            context.registerDelayed(.gigWouldBeStolen, expiry: .untilYourNextTurn)
        case .gigWouldBeStolen(let gig, let attackerUid) where context.isDelayedTrigger:
            protect(gig, attackerUid: attackerUid, &context)
        default:
            break
        }
    }

    private func protect(_ gig: Gig, attackerUid: Int, _ context: inout EffectContext) {
        guard let attacker = context.unit(context.rival, attackerUid), attacker.isLegend,
              gig.value < context.power(of: attacker, owner: context.rival, attacking: true) else { return }
        context.prevent()
    }
}
