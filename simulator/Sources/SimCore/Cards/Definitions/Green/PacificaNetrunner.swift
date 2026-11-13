struct PacificaNetrunner: GameCard {
    let data: CardData
    let listens: EventMask = .played

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .played = event, context.isAboutItself,
              let streetCred = context.streetCred(), streetCred % 2 == 0 else { return }
        let rival = context.rival
        guard let target = context.bestRivalUnit(where: { $0.spent }) ?? context.bestRivalUnit() else { return }
        context.forbidReadyUntilYourNextTurn(rival, uid: target.uid)
    }

    func playValue(in query: EffectQuery) -> Double? {
        let evenWithTarget = (query.streetCred() ?? 1) % 2 == 0 && query.field(of: query.rival).contains { $0.spent }
        return standardPlayValue(in: query).map { $0 + (evenWithTarget ? 5 : 0) }
    }
}
