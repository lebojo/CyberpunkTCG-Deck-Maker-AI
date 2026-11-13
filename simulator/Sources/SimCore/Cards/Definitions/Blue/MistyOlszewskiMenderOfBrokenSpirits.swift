struct MistyOlszewskiMenderOfBrokenSpirits: GameCard {
    let data: CardData
    let listens: EventMask = .endOfTurn

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .endOfTurn = event, context.selfUid != nil, context.deckCount() > 0 else { return }
        let chosen = mostCommonTypeInDeck(context)
        guard let top = context.takeTop(1).first else { return }
        if context.stats(top).kind == chosen {
            context.note("P\(context.owner) reveals \(context.data(top).name) (\(chosen.rawValue)) and keeps it")
            context.addToHand(top)
            context.readyEddies(1)
        } else {
            context.note("P\(context.owner) reveals \(context.data(top).name) and trashes it")
            context.putInTrash([top])
        }
    }

    private func mostCommonTypeInDeck(_ context: EffectContext) -> CardKind {
        let deck = context.game.players[context.owner].deck
        let kinds: [CardKind] = [.unit, .gear, .program]
        let counts = kinds.map { kind in deck.filter { context.stats($0).kind == kind }.count }
        let best = counts.indices.max { counts[$0] < counts[$1] } ?? 0
        return kinds[best]
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + 6 }
    }
}
