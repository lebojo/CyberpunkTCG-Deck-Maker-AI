struct AltCunninghamSoulkillerArchitect: GameCard {
    let data: CardData
    let listens: EventMask = []
    var hints: AIHints { .with { $0.manaReluctance = 6 } }

    static let discountNextProgram = 0
    static let replayFromTrash = 1

    var abilities: [ActivatedAbility] {
        [
            ActivatedAbility(index: Self.discountNextProgram, name: "Alt : réduction du prochain Program", timing: .beforePlayingCard),
            ActivatedAbility(index: Self.replayFromTrash, name: "Alt : rejouer un Program de la défausse", timing: .endOfMainPhase, eddieCost: 1),
        ]
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        switch ability.index {
        case Self.discountNextProgram:
            guard let played = query.subjectCardId, query.stats(played).kind == .program else { return [] }
            let gain = min(query.minGigCount(), query.stats(played).costValue - 1)
            return gain >= 2 ? [AbilityOption(ability: ability.index, target: .card(played))] : []
        default:
            return query.wasUsedThisTurn(query.onceKey(Self.replayFromTrash)) ? [] : [AbilityOption(ability: ability.index, eddieCost: 1)]
        }
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard let slot = context.selfLegendSlot, !context.legends()[slot].spent else { return false }
        switch option.ability {
        case Self.discountNextProgram:
            context.spendLegend(slot: slot)
            context.discountNext(.program, by: context.minGigCount())
            return true
        default:
            return replayFromTrash(slot, &context)
        }
    }

    private func replayFromTrash(_ slot: Int, _ context: inout EffectContext) -> Bool {
        var best: (index: Int, value: Double)?
        let trash = context.trash()
        for (index, id) in trash.enumerated() where context.stats(id).kind == .program && context.stats(id).costValue + 1 <= context.availableMana - 1 {
            if let value = context.playValue(id, from: .trash), value >= 18, value > (best?.value ?? 0) { best = (index, value) }
        }
        guard let choice = best else { return false }
        let id = trash[choice.index]
        guard context.payEddies(1 + context.stats(id).costValue) else { return false }
        _ = context.useOncePerTurn(context.onceKey(Self.replayFromTrash))
        _ = context.takeFromTrash(at: choice.index)
        context.spendLegend(slot: slot)
        context.playProgram(id, bottomAfter: true)
        return true
    }
}
