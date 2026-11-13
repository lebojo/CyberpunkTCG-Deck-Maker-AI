struct MeredithStoutStoneColdCorpo: GameCard {
    let data: CardData
    let listens: EventMask = .gigsAlteredByRival
    var modifierScopes: ModifierScopes { .fight }

    func modifiers(in query: EffectQuery) -> CardModifiers {
        guard query.fightOpponent?.isLegend == true else { return .none }
        return .with { $0.fightPower = 2 }
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .gigsAlteredByRival = event else { return }
        let trash = context.trash()
        guard let best = trash.indices.max(by: { context.keepValue(trash[$0]) < context.keepValue(trash[$1]) }),
              let recovered = context.takeFromTrash(at: best) else { return }
        context.addToHand(recovered)
    }
}
