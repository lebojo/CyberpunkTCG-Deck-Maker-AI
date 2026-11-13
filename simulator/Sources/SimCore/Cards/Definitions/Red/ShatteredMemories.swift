struct ShatteredMemories: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    private static let handSize = 5

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        let owner = context.owner
        let rival = context.rival
        let discarded = discardHand(of: owner, &context) + discardHand(of: rival, &context)
        refillHand(of: owner, &context)
        refillHand(of: rival, &context)
        if context.gigs().contains(where: { $0.value == discarded }), context.deckCount() > 2 {
            context.draw(2)
        }
    }

    private func discardHand(of p: Int, _ context: inout EffectContext) -> Int {
        let hand = context.hand(of: p)
        for id in hand { context.discard(id, from: p) }
        return hand.count
    }

    private func refillHand(of p: Int, _ context: inout EffectContext) {
        guard context.deckCount(of: p) > Self.handSize else { return }
        context.draw(Self.handSize, for: p)
    }

    func playValue(in query: EffectQuery) -> Double? {
        let mine = query.hand().count - 1
        let theirs = query.hand(of: query.rival).count
        guard mine <= 2, theirs >= mine + 2, query.deckCount() > Self.handSize else { return nil }
        return 12 + Double(theirs - mine) * 3
    }
}
