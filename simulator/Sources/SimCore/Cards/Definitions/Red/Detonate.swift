struct Detonate: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event, let target = target(context) else { return }
        context.defeatGear(target)
    }

    private func target(_ reading: some GameReading) -> GearTarget? {
        reading.bestRivalGear { reading.stats($0).power <= 2 }
    }

    func playValue(in query: EffectQuery) -> Double? {
        target(query) != nil ? 26 : nil
    }
}
