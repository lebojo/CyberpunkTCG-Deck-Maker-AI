struct GildedMaton: GameCard {
    let data: CardData
    let listens: EventMask = .played

    private static let maximumTargetCost = 3

    private struct Trade {
        let gear: GearTarget
        let target: FieldUnit
        let margin: Double
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .played = event, context.isAboutItself, let trade = bestTrade(in: context) else { return }
        context.defeatGear(trade.gear)
        context.defeat(context.rival, uid: trade.target.uid)
    }

    private func bestTrade(in reading: some GameReading) -> Trade? {
        let rival = reading.rival
        let targets = reading.field(of: rival).filter { reading.stats($0.cardId).costValue <= Self.maximumTargetCost }
        let trades = friendlyGears(reading).flatMap { gear in
            targets.compactMap { trade(gear, $0, reading) }
        }
        return trades.max { $0.margin < $1.margin }
    }

    private func trade(_ gear: GearTarget, _ target: FieldUnit, _ reading: some GameReading) -> Trade? {
        guard reading.stats(gear.gear).costValue <= reading.stats(target.cardId).costValue else { return nil }
        let gain = reading.unitThreat(target, owner: reading.rival)
        return Trade(gear: gear, target: target, margin: gain - gearWorth(gear, reading))
    }

    private func gearWorth(_ target: GearTarget, _ reading: some GameReading) -> Double {
        Double(reading.stats(target.gear).costValue * 2 + reading.stats(target.gear).power)
    }

    private func friendlyGears(_ reading: some GameReading) -> [GearTarget] {
        let owner = reading.owner
        let onUnits = reading.field().flatMap { unit in unit.gears.map { GearTarget(owner: owner, host: .unit(unit.uid), gear: $0) } }
        let onLegends = reading.legends().enumerated().flatMap { slot, legend in legend.gears.map { GearTarget(owner: owner, host: .legend(slot), gear: $0) } }
        return onUnits + onLegends
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + (bestTrade(in: query) != nil ? 3 : 0) }
    }
}
