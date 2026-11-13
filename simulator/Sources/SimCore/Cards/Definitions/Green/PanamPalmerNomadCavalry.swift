struct PanamPalmerNomadCavalry: GameCard {
    let data: CardData
    let listens: EventMask = .endOfTurn
    var hints: AIHints { .with { $0.manaReluctance = 4 } }

    static let equippedThreshold = 5

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Panam : move a Gear", timing: .mainAction, eddieCost: 2)]
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .endOfTurn = event, context.selfLegendSlot != nil, equippedCount(context) >= Self.equippedThreshold else { return }
        context.note("P\(context.owner) readies every equipped Unit and Legend")
        let owner = context.owner
        for unit in context.field() where unit.isEquipped { context.readyUnit(owner, uid: unit.uid) }
        for slot in context.legends().indices where context.legends()[slot].faceUp && !context.legends()[slot].gears.isEmpty {
            context.readyLegend(slot: slot)
        }
    }

    private func equippedCount(_ reading: some GameReading) -> Int {
        let units = reading.field().filter(\.isEquipped).count
        let legends = reading.legends().filter { $0.faceUp && !$0.gears.isEmpty }.count
        return units + legends
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        guard query.availableMana >= 2, let slot = query.selfLegendSlot, let gear = bestGear(on: slot, in: query),
              let unit = bestUnequippedUnit(in: query) else { return [] }
        let value = 12 + Double(query.stats(gear).power) * 3 + (unit.spent ? 6 : 0)
        return [AbilityOption(ability: 0, target: .unit(owner: query.owner, uid: unit.uid), value: value, eddieCost: 2)]
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard let slot = context.selfLegendSlot, !context.legends()[slot].spent, let gear = bestGear(on: slot, in: context),
              let unit = bestUnequippedUnit(in: context), context.payEddies(2) else { return false }
        if !context.legends()[slot].spent { context.spendLegend(slot: slot) }
        context.moveGear(gear, from: .legend(slot), to: .unit(unit.uid))
        context.readyUnit(context.owner, uid: unit.uid)
        return true
    }

    private func bestGear(on slot: Int, in reading: some GameReading) -> Int? {
        guard reading.legends().indices.contains(slot) else { return nil }
        return reading.legends()[slot].gears.max { reading.stats($0).power < reading.stats($1).power }
    }

    private func bestUnequippedUnit(in reading: some GameReading) -> FieldUnit? {
        let owner = reading.owner
        return reading.field().filter { !$0.isEquipped }.max { reading.unitThreat($0, owner: owner) < reading.unitThreat($1, owner: owner) }
    }
}
