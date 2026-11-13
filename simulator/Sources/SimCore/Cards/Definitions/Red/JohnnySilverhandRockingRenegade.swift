struct JohnnySilverhandRockingRenegade: GameCard {
    let data: CardData
    let listens: EventMask = []
    var hints: AIHints { .with { $0.manaReluctance = 6 } }

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Johnny : attaquer dès l'entrée en jeu", timing: .mainAction)]
    }

    private func price(_ reading: some GameReading) -> Int {
        max(0, 2 - reading.friendlyGigsWith8PlusValue)
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        let cost = price(query)
        guard query.availableMana - 1 >= cost else { return [] }
        return query.field().compactMap { option(for: $0, cost: cost, query) }
    }

    private func option(for unit: FieldUnit, cost: Int, _ query: EffectQuery) -> AbilityOption? {
        let owner = query.owner
        let rival = query.rival
        guard unit.lagging, !query.canAttack(unit, owner: owner),
              !query.game.keywords(owner, unit).contains(.cannotAttack) else { return nil }
        let bonus = query.data(unit.cardId).has(.rocker) ? 2 : 0
        let attackPower = query.power(of: unit, owner: owner, attacking: true) + bonus
        let hasTarget = query.field(of: rival).contains { $0.spent && query.power(of: $0, owner: rival) <= attackPower }
        guard hasTarget else { return nil }
        return AbilityOption(ability: 0, target: .unit(owner: owner, uid: unit.uid), value: 24 + Double(attackPower), eddieCost: cost)
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard case .unit(let unitOwner, let uid) = option.target, let unit = context.unit(unitOwner, uid),
              let slot = context.selfLegendSlot, !context.legends()[slot].spent else { return false }
        let cost = price(context)
        guard context.availableMana - 1 >= cost else { return false }
        context.spendLegend(slot: slot)
        guard context.payEddies(cost) else { return false }
        context.grantKeyword(.attacksUnitsWhenPlayed, to: unitOwner, uid: uid)
        if context.data(unit.cardId).has(.rocker) { context.addPower(unitOwner, uid: uid, 2) }
        return true
    }
}
