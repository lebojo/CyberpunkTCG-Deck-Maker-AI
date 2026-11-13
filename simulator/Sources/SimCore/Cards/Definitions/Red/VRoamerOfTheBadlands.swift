struct VRoamerOfTheBadlands: GameCard {
    let data: CardData
    let listens: EventMask = [.gigStolen, .endOfTurn]

    func action(_ event: GameEvent, in context: inout EffectContext) {
        switch event {
        case .gigStolen(let gig, _) where context.isAboutItself:
            raiseStolenGig(gig, &context)
        case .endOfTurn:
            guard context.selfUid != nil, context.friendlyGigsWith8PlusValue >= 2 else { return }
            context.draw(1)
        default:
            break
        }
    }

    private func raiseStolenGig(_ gig: Gig, _ context: inout EffectContext) {
        let gigs = context.gigs()
        guard let index = gigs.lastIndex(where: { $0.sides == gig.sides && $0.value == gig.value }) else { return }
        let ceiling = min(gig.sides, gig.value + 5)
        let best = (gig.value...ceiling).max { score(of: $0, at: index, in: gigs, context) <= score(of: $1, at: index, in: gigs, context) }
        guard let value = best, value != gig.value else { return }
        context.setGig(context.owner, index: index, to: value)
    }

    private func score(of value: Int, at index: Int, in gigs: [Gig], _ reading: some GameReading) -> Double {
        var trial = gigs
        trial[index].value = value
        return reading.gigScore(trial)
    }

    func attackValueBonus(in query: EffectQuery) -> Double { 6 }
}
