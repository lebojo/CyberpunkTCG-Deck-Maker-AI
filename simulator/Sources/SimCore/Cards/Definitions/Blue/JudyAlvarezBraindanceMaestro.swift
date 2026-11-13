struct JudyAlvarezBraindanceMaestro: GameCard {
    let data: CardData
    let listens: EventMask = [.played, .quickActivated]
    var hints: AIHints { .with { $0.manaReluctance = 5 } }

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Judy : défausser le dessus du deck", timing: .mainAction)]
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        switch event {
        case .played(let id, _), .quickActivated(let id):
            guard context.stats(id).kind == .program, context.data(id).has(.braindance) else { return }
            boostAnAlly(&context)
        default:
            break
        }
    }

    private func boostAnAlly(_ context: inout EffectContext) {
        guard let target = context.bestAllyUnit() else { return }
        context.addPower(context.owner, uid: target.uid, 1)
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        query.deckCount() > 0 ? [AbilityOption(ability: 0, value: 6)] : []
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard let slot = context.selfLegendSlot, !context.legends()[slot].spent, context.deckCount() > 0 else { return false }
        context.spendLegend(slot: slot)
        let milled = context.trashTop(1)
        if let id = milled.first, context.stats(id).kind == .program, context.takeLastFromTrash(id) {
            context.addToHand(id)
        }
        return true
    }
}
