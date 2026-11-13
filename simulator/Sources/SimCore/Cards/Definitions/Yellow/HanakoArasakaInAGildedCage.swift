struct HanakoArasakaInAGildedCage: GameCard {
    let data: CardData
    let listens: EventMask = .played

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .played = event, context.isAboutItself else { return }
        let values = Set(context.gigs().map(\.value))
        let game = context.game
        _ = context.searchTop(4, take: 4, where: { values.contains(game.stats($0).costValue) })
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + (query.gigs().isEmpty ? 0 : 3) }
    }
}
