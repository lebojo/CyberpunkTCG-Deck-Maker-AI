struct DexterDeShawnOffTheGrid: GameCard {
    let data: CardData
    let listens: EventMask = .calledAsLegend
    var hints: AIHints { .with { $0.manaReluctance = 6 } }

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Dexter : augmenter un Gig", timing: .mainAction)]
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .calledAsLegend = event, context.isAboutItself else { return }
        let choice = bestPump(context)
        let options = [ModeOption(name: "give a friendly Unit +2 power", value: choice.value), ModeOption(name: "draw 1", value: ModeOption.drawOne)]
        _ = context.chooseMode(options) { mode, branch in
            if mode == 0 { pump(choice.target ?? branch.bestAllyUnit(), &branch) } else { branch.draw(1) }
        }
    }

    private static let extraGigValue = 8.0

    private func bestPump(_ reading: some GameReading) -> (target: FieldUnit?, value: Double) {
        if let swing = reading.bestFightSwing(allyBonus: 2, rivalMalus: 0) { return (swing.ally, swing.value) }
        let owner = reading.owner
        let stealer = reading.field().first { unit in
            guard reading.canAttack(unit, owner: owner), reading.canStealGigs(unit, owner: owner) else { return false }
            let power = reading.power(of: unit, owner: owner, attacking: true)
            return reading.stealCount(forPower: power + 2) > reading.stealCount(forPower: power)
        }
        return stealer.map { ($0, Self.extraGigValue) } ?? (nil, 1)
    }

    private func pump(_ target: FieldUnit?, _ context: inout EffectContext) {
        guard let target else { return }
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
