struct SafetyOverride: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Safety Override", timing: .fight, spendsSource: false)]
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        let cost = query.effectiveCost(query.cardId)
        guard cost <= query.availableMana, !query.hasDelayedTrigger() else { return [] }
        return [AbilityOption(ability: 0, eddieCost: cost, fight: .retaliation)]
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard context.playQuickFromHand(context.cardId) else { return false }
        armRetaliation(&context)
        return true
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        switch event {
        case .programResolves:
            armRetaliation(&context)
        case .lostFight(let report) where context.isDelayedTrigger:
            context.defeatAfterFight(context.rival, uid: report.opponentUid)
            context.consumeDelayedTrigger()
        default:
            break
        }
    }

    private func armRetaliation(_ context: inout EffectContext) {
        context.registerDelayed(.lostFight, expiry: .untilYourNextTurn)
    }

    func playValue(in query: EffectQuery) -> Double? { nil }

    func keepValue(in query: EffectQuery) -> Double { 9 }
}
