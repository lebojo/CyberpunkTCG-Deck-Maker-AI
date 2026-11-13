struct MuamarReyesElCapitan: GameCard {
    let data: CardData
    let listens: EventMask = .calledAsLegend
    var hints: AIHints { .with { $0.manaReluctance = 3 } }

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Muamar Reyes : ajuster un Gig de 1", timing: .mainAction)]
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        switch event {
        case .calledAsLegend where context.isAboutItself:
            chooseCallEffect(&context)
        case .wouldBeDefeated(let uid, let cause) where context.isDelayedTrigger:
            guard case .fight = cause, uid == context.delayedPayload else { return }
            context.prevent()
        default:
            break
        }
    }

    private func chooseCallEffect(_ context: inout EffectContext) {
        _ = context.chooseMode(2) { mode, branch in
            if mode == 0 { protectBestUnit(&branch) } else { branch.draw(1) }
        }
    }

    private func protectBestUnit(_ context: inout EffectContext) {
        guard let unit = context.bestAllyUnit() else { return }
        context.registerDelayed(.wouldBeDefeated, expiry: .endOfTurn, charges: 1, payload: unit.uid)
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        guard query.bestGigAdjustment(up: 1, down: 1) != nil else { return [] }
        return [AbilityOption(ability: 0, value: 7)]
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard context.adjustGigBest(by: 1) else { return false }
        context.spendSelf()
        return true
    }
}
