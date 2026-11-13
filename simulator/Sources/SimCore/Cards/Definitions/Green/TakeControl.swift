struct TakeControl: GameCard {
    let data: CardData
    let listens: EventMask = []

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Take Control", timing: .rivalAttacksGigs, spendsSource: false)]
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        let cost = query.effectiveCost(query.cardId)
        guard cost <= query.availableMana else { return [] }
        return [AbilityOption(ability: 0, eddieCost: cost, stealReduction: 1)]
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        context.playQuickFromHand(context.cardId)
    }

    func playValue(in query: EffectQuery) -> Double? { nil }

    func keepValue(in query: EffectQuery) -> Double { 12 }
}
