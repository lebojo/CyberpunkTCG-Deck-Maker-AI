struct RebootOptics: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Reboot Optics", timing: .fight, spendsSource: false)]
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        switch event {
        case .programResolves:
            context.registerDelayed([.wouldBeDefeated, .wonFight], expiry: .endOfTurn)
        case .wouldBeDefeated(_, .fight) where context.isDelayedTrigger:
            context.prevent()
            context.consumeDelayedTrigger()
        case .wonFight where context.isDelayedTrigger:
            context.consumeDelayedTrigger()
        default:
            break
        }
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        let cost = query.effectiveCost(query.cardId)
        guard cost <= query.availableMana, query.fightOwnUnit != nil, query.fightOpponent != nil, !query.hasDelayedTrigger() else { return [] }
        return [AbilityOption(ability: 0, eddieCost: cost, fight: .retaliation)]
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard context.playQuickFromHand(context.cardId) else { return false }
        context.registerDelayed([.wouldBeDefeated, .wonFight], expiry: .endOfTurn)
        return true
    }

    func playValue(in query: EffectQuery) -> Double? { nil }

    func keepValue(in query: EffectQuery) -> Double { 9 }
}
