struct MaxTacAV: GameCard {
    let data: CardData
    let listens: EventMask = .played

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .played = event, context.isAboutItself, let swap = context.game.bestNetGigSwap(context.owner) else { return }
        context.note("P\(context.owner) swaps a Gig with the rival")
        context.swapGigs(mine: swap.mine, theirs: swap.theirs)
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + (query.gigs(of: query.rival).isEmpty ? 0 : 3) }
    }
}
