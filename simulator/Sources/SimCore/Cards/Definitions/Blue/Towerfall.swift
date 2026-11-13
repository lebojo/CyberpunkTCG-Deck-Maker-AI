struct Towerfall: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        let rival = context.rival
        if context.hasLessStreetCred {
            for unit in context.field(of: rival) { context.addPower(rival, uid: unit.uid, -5) }
        }
        for unit in context.field(of: rival) where context.power(of: unit, owner: rival) == 0 {
            context.bottomDeckUnit(rival, uid: unit.uid)
        }
    }

    func playValue(in query: EffectQuery) -> Double? {
        let rival = query.rival
        let weak = query.field(of: rival).filter { query.power(of: $0, owner: rival) <= 5 }.count
        if query.hasLessStreetCred, weak >= 1 { return 20 + Double(weak) * 12 }
        let zero = query.field(of: rival).filter { query.power(of: $0, owner: rival) == 0 }.count
        return zero >= 1 ? 16 + Double(zero) * 6 : nil
    }
}
