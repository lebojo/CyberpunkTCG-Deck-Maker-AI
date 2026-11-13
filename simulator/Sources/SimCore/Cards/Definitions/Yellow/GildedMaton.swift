struct GildedMaton: GameCard {
    let data: CardData
    let listens: EventMask = .played

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .played = event, context.isAboutItself else { return }
        let rival = context.rival
        guard let target = context.bestRivalUnit(where: { context.stats($0.cardId).costValue <= 3 }) else { return }
        guard let gear = cheapestFriendlyGear(context), context.stats(gear.gear).costValue <= context.stats(target.cardId).costValue else { return }
        context.defeatGear(gear)
        context.defeat(rival, uid: target.uid)
    }

    private func cheapestFriendlyGear(_ context: EffectContext) -> GearTarget? {
        friendlyGears(context).min { gearWorth($0, context) < gearWorth($1, context) }
    }

    private func gearWorth(_ target: GearTarget, _ context: EffectContext) -> Int {
        context.stats(target.gear).costValue * 2 + context.stats(target.gear).power
    }

    private func friendlyGears(_ context: EffectContext) -> [GearTarget] {
        let owner = context.owner
        let onUnits = context.field().flatMap { unit in unit.gears.map { GearTarget(owner: owner, host: .unit(unit.uid), gear: $0) } }
        let onLegends = context.legends().enumerated().flatMap { slot, legend in legend.gears.map { GearTarget(owner: owner, host: .legend(slot), gear: $0) } }
        return onUnits + onLegends
    }

    func playValue(in query: EffectQuery) -> Double? {
        let hasTarget = query.field(of: query.rival).contains { query.stats($0.cardId).costValue <= 3 }
        return standardPlayValue(in: query).map { $0 + (hasTarget ? 3 : 0) }
    }
}
