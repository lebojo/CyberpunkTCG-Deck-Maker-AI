struct WakakoOkadaPeaceAndHarmony: GameCard {
    let data: CardData
    let listens: EventMask = .calledAsLegend
    var hints: AIHints { .with { $0.manaReluctance = 5 } }

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Wakako : diminuer un Gig", timing: .mainAction)]
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .calledAsLegend = event, context.isAboutItself else { return }
        let swing = context.bestFightSwing(allyBonus: 0, rivalMalus: 2)
        let options = [ModeOption(name: "give a rival Unit -2 power", value: swing?.value ?? 1), ModeOption(name: "draw 1", value: ModeOption.drawOne)]
        _ = context.chooseMode(options) { mode, branch in
            if mode == 0 {
                weaken(swing?.rival ?? branch.bestRivalUnit(), &branch)
            } else {
                branch.draw(1)
            }
        }
    }

    private func weaken(_ target: FieldUnit?, _ context: inout EffectContext) {
        guard let target else { return }
        context.addPower(context.rival, uid: target.uid, -2)
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        query.bestGigAdjustment(up: 0, down: 2) == nil ? [] : [AbilityOption(ability: 0, value: 9)]
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard let slot = context.selfLegendSlot, !context.legends()[slot].spent, context.bestGigAdjustment(up: 0, down: 2) != nil else { return false }
        context.spendLegend(slot: slot)
        return context.decreaseGigBest(by: 2)
    }
}
