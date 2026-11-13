struct AdamSmasherEnderOfLegends: GameCard {
    let data: CardData
    let listens: EventMask = .played
    var hints: AIHints { .with { $0.goSoloBonus = 10 } }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .played = event, context.isAboutItself, let target = context.bestRivalUnit() else { return }
        context.defeat(context.rival, uid: target.uid)
    }
}
