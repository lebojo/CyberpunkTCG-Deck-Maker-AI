struct JackieWellesPourOneOutForMe: GameCard {
    let data: CardData
    let listens: EventMask = .played
    var hints: AIHints { .with { $0.manaReluctance = 3 } }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .played(let played, _) = event else { return }
        let stats = context.stats(played)
        guard stats.color == .blue, stats.kind == .unit || stats.kind == .gear else { return }
        guard context.useOncePerTurn(context.onceKey()) else { return }
        guard let choice = context.bestGigAdjustment(up: 0, down: 2) else { return }
        context.setGig(context.owner, index: choice.index, to: choice.value)
        if choice.value == 1 { context.draw(1) }
    }
}
