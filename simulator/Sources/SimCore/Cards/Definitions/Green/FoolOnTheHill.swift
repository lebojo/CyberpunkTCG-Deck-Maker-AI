struct FoolOnTheHill: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        let looked = context.takeTop(2)
        guard !looked.isEmpty else { return }
        _ = context.chooseMode(2, chooser: context.rival) { mode, branch in
            if mode == 0 {
                for id in looked { branch.addToHand(id) }
            } else {
                branch.putInTrash(looked)
                branch.draw(2)
            }
        }
    }

    func playValue(in query: EffectQuery) -> Double? {
        query.deckCount() >= 2 ? 13 : nil
    }
}
