struct GoroTakemuraVengefulBodyguard: GameCard {
    let data: CardData
    let listens: EventMask = .blocked
    var hints: AIHints { .with { $0.manaReluctance = 4 } }

    static let maximumCost = 4
    static let discardThreshold = 14.0

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Goro Takemura : +1 power en combat", timing: .fight, eddieCost: 1)]
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .blocked = event, context.isAboutAlly else { return }
        guard let worst = context.hand().min(by: { context.keepValue($0) < context.keepValue($1) }),
              context.keepValue(worst) < Self.discardThreshold else { return }
        context.discard(worst)
        context.draw(1)
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        guard query.availableMana >= 1, query.valuePairs() >= 1,
              let own = query.fightOwnUnit, query.stats(own.cardId).costValue <= Self.maximumCost else { return [] }
        return [AbilityOption(ability: 0, target: .unit(owner: query.owner, uid: own.uid), eddieCost: 1, fight: .power(own: 1, other: 0))]
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard case .unit(let unitOwner, let uid) = option.target, let target = context.unit(unitOwner, uid),
              context.stats(target.cardId).costValue <= Self.maximumCost,
              let slot = context.selfLegendSlot, !context.legends()[slot].spent,
              context.payEddies(1) else { return false }
        if !context.legends()[slot].spent { context.spendLegend(slot: slot) }
        context.grantKeyword(.blocker, to: unitOwner, uid: uid)
        if context.valuePairs() >= 1 { context.addPower(unitOwner, uid: uid, 1) }
        return true
    }
}
