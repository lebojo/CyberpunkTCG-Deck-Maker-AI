struct HackedCorpo: GameCard {
    let data: CardData
    let listens: EventMask = .played

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .played = event, context.isAboutItself else { return }
        let milled = context.trashTop(3)
        let programs = milled.filter { context.stats($0).kind == .program }
        guard let best = programs.max(by: { context.keepValue($0) < context.keepValue($1) }),
              context.takeLastFromTrash(best) else { return }
        context.addToHand(best)
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + 3 }
    }
}
