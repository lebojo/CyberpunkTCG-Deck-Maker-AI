struct SixthStreetRecruits: GameCard {
    let data: CardData
    let listens: EventMask = .gigStolen

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .gigStolen(let gig, _) = event, gig.sides == 6 else { return }
        context.increaseGigBest(by: 6)
    }
}
