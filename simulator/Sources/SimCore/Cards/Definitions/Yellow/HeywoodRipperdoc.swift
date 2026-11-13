struct HeywoodRipperdoc: GameCard {
    let data: CardData
    let listens: EventMask = .played

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .played = event, context.isAboutItself else { return }
        let values = Set(context.gigs().map(\.value))
        let game = context.game
        let matching = context.bestRivalGear { values.contains(game.stats($0).costValue) }
        guard let target = matching ?? context.bestRivalGear() else { return }
        let drawsCard = values.contains(context.stats(target.gear).costValue)
        context.defeatGear(target)
        if drawsCard { context.draw(1) }
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + (query.bestRivalGear() == nil ? 0 : 6) }
    }
}
