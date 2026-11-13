struct BonnieAndClyde: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        let rival = context.rival
        var defeated: [Int] = []
        for _ in 0..<defeatCount(context) {
            guard let target = context.bestRivalUnit(where: { !defeated.contains($0.uid) && context.power(of: $0, owner: rival) <= 4 }) else { return }
            defeated.append(target.uid)
            context.defeat(rival, uid: target.uid)
        }
    }

    private func defeatCount(_ reading: some GameReading) -> Int {
        reading.gigs(of: reading.rival).count - reading.gigs().count >= 2 ? 2 : 1
    }

    func playValue(in query: EffectQuery) -> Double? {
        let rival = query.rival
        let targets = query.field(of: rival).filter { query.power(of: $0, owner: rival) <= 4 }.count
        guard targets > 0 else { return nil }
        return 28 + Double(min(targets, defeatCount(query)) - 1) * 12
    }
}
