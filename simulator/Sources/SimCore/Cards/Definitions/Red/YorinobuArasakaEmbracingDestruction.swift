struct YorinobuArasakaEmbracingDestruction: GameCard {
    let data: CardData
    let listens: EventMask = .attackDeclared
    var hints: AIHints { .with { $0.manaReluctance = 3 } }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .attackDeclared(let attackerUid, _) = event,
              let attacker = context.unit(context.owner, attackerUid),
              context.data(attacker.cardId).has(.arasaka),
              context.useOncePerTurn(context.onceKey()) else { return }
        context.draw(1)
        if let streetCred = context.streetCred(), streetCred < 20 { context.discardWorst() }
    }
}
