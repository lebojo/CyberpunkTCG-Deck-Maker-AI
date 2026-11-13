struct HanakoArasakaDaughterOfTheEmperor: GameCard {
    let data: CardData
    let listens: EventMask = .turnStarted
    var hints: AIHints { .with { $0.manaReluctance = 6 } }

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Hanako : échanger un Gig", timing: .beforeAttacks)]
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .turnStarted = event else { return }
        context.draw(context.valuePairs())
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        guard !query.gigs().isEmpty, !query.gigs(of: query.rival).isEmpty else { return [] }
        return [AbilityOption(ability: 0)]
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard let slot = context.selfLegendSlot, !context.legends()[slot].spent,
              !context.gigs().isEmpty, !context.gigs(of: context.rival).isEmpty,
              let swap = context.bestGigSwap(margin: 2) else { return false }
        context.spendLegend(slot: slot)
        context.swapGigs(mine: swap.mine, theirs: swap.theirs, notifyingRival: false)
        return true
    }
}
