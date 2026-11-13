struct RiverWardDetectiveOnTheHunt: GameCard {
    let data: CardData
    let listens: EventMask = .defeated
    var hints: AIHints { .with { $0.manaReluctance = 6 } }

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "River Ward : Gear gratuit", timing: .mainAction)]
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .defeated(let report) = event, report.wasEquipped else { return }
        let looked = context.takeTop(2)
        guard let worst = looked.min(by: { context.stats($0).costValue < context.stats($1).costValue }) else { return }
        context.putInTrash([worst])
        context.putOnTop(looked.filter { $0 != worst })
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        query.hand().compactMap { id in
            guard query.stats(id).kind == .gear, query.stats(id).costValue <= 2, let value = query.playValue(id) else { return nil }
            return AbilityOption(ability: 0, target: .card(id), value: value + 40)
        }
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard case .card(let id) = option.target, let slot = context.selfLegendSlot, !context.legends()[slot].spent else { return false }
        guard context.playFromHand(id, free: true) else { return false }
        context.spendLegend(slot: slot)
        return true
    }
}
