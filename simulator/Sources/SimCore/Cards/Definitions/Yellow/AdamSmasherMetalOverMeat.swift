struct AdamSmasherMetalOverMeat: GameCard {
    let data: CardData
    let listens: EventMask = .played

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .played = event, context.isAboutItself, let selfUid = context.selfUid else { return }
        let owner = context.owner
        for side in [context.rival, owner] {
            for unit in context.field(of: side) where side != owner || unit.uid != selfUid {
                context.defeat(side, uid: unit.uid)
            }
        }
    }

    func playValue(in query: EffectQuery) -> Double? {
        guard let base = standardPlayValue(in: query) else { return nil }
        let swing = totalThreat(of: query.rival, in: query) - totalThreat(of: query.owner, in: query)
        return swing < -8 ? nil : base - 20 + swing * 0.6
    }

    private func totalThreat(of player: Int, in query: EffectQuery) -> Double {
        query.field(of: player).reduce(0) { $0 + query.unitThreat($1, owner: player) }
    }
}
