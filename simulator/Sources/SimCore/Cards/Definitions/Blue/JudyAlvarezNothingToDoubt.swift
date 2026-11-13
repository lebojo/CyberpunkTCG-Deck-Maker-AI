struct JudyAlvarezNothingToDoubt: GameCard {
    let data: CardData
    let listens: EventMask = []
    var hints: AIHints { .with { $0.threatBonus = 2 } }

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Judy : révéler et jouer le dessus du deck", timing: .mainAction, eddieCost: 1)]
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        guard query.deckCount() > 0, query.availableMana >= 1 else { return [] }
        return [AbilityOption(ability: 0, value: 9, eddieCost: 1)]
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard context.selfUnit?.spent == false, context.deckCount() > 0, context.payEddies(1) else { return false }
        context.spendSelf()
        guard let id = context.takeTop(1).first else { return false }
        context.note("P\(context.owner) reveals \(context.data(id).name)")
        if context.playValue(id) != nil, context.playForFree(id) { return true }
        context.addToHand(id)
        return true
    }
}
