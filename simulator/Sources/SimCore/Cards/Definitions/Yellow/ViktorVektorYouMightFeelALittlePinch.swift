struct ViktorVektorYouMightFeelALittlePinch: GameCard {
    let data: CardData
    let listens: EventMask = .played

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .played = event, context.isAboutItself, let selfUid = context.selfUid else { return }
        guard let host = context.bestAllyUnit(where: { $0.uid != selfUid }) else { return }
        guard let index = bestCyberwareIndex(context), let gear = context.takeFromTrash(at: index) else { return }
        if !context.playForFree(gear, equipTo: .unit(host.uid)) { context.putInTrash([gear]) }
    }

    private func bestCyberwareIndex(_ context: EffectContext) -> Int? {
        let trash = context.trash()
        return trash.indices
            .filter { isCheapCyberware(trash[$0], in: context) }
            .max { context.stats(trash[$0]).power < context.stats(trash[$1]).power }
    }

    private func isCheapCyberware(_ id: Int, in reading: some GameReading) -> Bool {
        let stats = reading.stats(id)
        return stats.kind == .gear && stats.costValue <= 2 && reading.data(id).has(.cyberware)
    }

    func playValue(in query: EffectQuery) -> Double? {
        let hasGear = query.trash().contains { isCheapCyberware($0, in: query) }
        return standardPlayValue(in: query).map { $0 + (hasGear && !query.field().isEmpty ? 5 : 0) }
    }
}
