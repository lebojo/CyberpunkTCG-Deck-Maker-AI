struct DexterDeShawnOffTheGrid: GameCard {
    let data: CardData
    let listens: EventMask = .calledAsLegend
    var hints: AIHints { .with { $0.manaReluctance = 6 } }

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Dexter : augmenter un Gig", timing: .mainAction)]
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .calledAsLegend = event, context.isAboutItself else { return }
        _ = context.chooseMode(2) { mode, branch in
            if mode == 0 { pumpBestAlly(&branch) } else { branch.draw(1) }
        }
    }

    private func pumpBestAlly(_ context: inout EffectContext) {
        guard let target = context.bestAllyUnit() else { return }
        context.addPower(context.owner, uid: target.uid, 2)
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        guard let choice = query.bestGigAdjustment(up: 2, down: 0) else { return [] }
        var improved = query.gigs()
        improved[choice.index].value = choice.value
        let gain = query.gigScore(improved) - query.gigScore(query.gigs())
        return [AbilityOption(ability: 0, value: 10 + gain * 3)]
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard let slot = context.selfLegendSlot, !context.legends()[slot].spent,
              context.increaseGigBest(by: 2) else { return false }
        context.spendLegend(slot: slot)
        return true
    }
}
