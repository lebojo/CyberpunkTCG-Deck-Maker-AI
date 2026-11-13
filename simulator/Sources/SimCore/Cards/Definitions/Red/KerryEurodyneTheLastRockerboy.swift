struct KerryEurodyneTheLastRockerboy: GameCard {
    let data: CardData
    let listens: EventMask = []

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Kerry : piocher 2", timing: .mainAction)]
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        guard query.friendlyGigsWith8PlusValue >= 1, let unit = query.selfUnit, !prefersAttacking(unit, query) else { return [] }
        return [AbilityOption(ability: 0, value: 16)]
    }

    private func prefersAttacking(_ unit: FieldUnit, _ query: EffectQuery) -> Bool {
        let owner = query.owner
        guard query.canAttack(unit, owner: owner), query.canStealGigs(unit, owner: owner) else { return false }
        return query.stealCount(forPower: query.power(of: unit, owner: owner, attacking: true)) > 0
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard context.selfUid != nil, context.friendlyGigsWith8PlusValue >= 1 else { return false }
        context.spendSelf()
        context.draw(2)
        return true
    }
}
