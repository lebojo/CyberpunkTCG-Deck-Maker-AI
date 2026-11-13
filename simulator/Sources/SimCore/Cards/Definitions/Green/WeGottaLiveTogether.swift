struct WeGottaLiveTogether: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves
    var modifierScopes: ModifierScopes { .ownPlayCost }

    static let maximumUnitCost = 3
    static let discountedCost = 3
    static let gigDeficit = 2

    func modifiers(in query: EffectQuery) -> CardModifiers {
        guard query.gigs(of: query.rival).count - query.gigs().count >= Self.gigDeficit else { return .none }
        return .with { $0.costOverride = Self.discountedCost }
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        for _ in 0..<2 {
            guard let index = bestTrashIndex(in: context), let id = context.takeFromTrash(at: index) else { return }
            context.note("P\(context.owner) plays \(context.data(id).name) from the trash")
            context.playForFree(id)
        }
    }

    private func candidateIndices(in reading: some GameReading) -> [Int] {
        let trash = reading.trash()
        return trash.indices.filter { reading.stats(trash[$0]).kind == .unit && reading.stats(trash[$0]).costValue <= Self.maximumUnitCost }
    }

    private func bestTrashIndex(in reading: some GameReading) -> Int? {
        let trash = reading.trash()
        return candidateIndices(in: reading).max { value(trash[$0], reading) < value(trash[$1], reading) }
    }

    private func value(_ id: Int, _ reading: some GameReading) -> Double {
        let stats = reading.stats(id)
        return Double(stats.power) * 1.2 + Double(stats.costValue) * 1.5
    }

    func playValue(in query: EffectQuery) -> Double? {
        let count = min(2, candidateIndices(in: query).count)
        return count == 0 ? nil : 8 + Double(count) * 10
    }
}
