struct FoolOnTheHill: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        let looked = context.takeTop(2)
        guard !looked.isEmpty else { return }
        let options = [
            ModeOption(name: "let the revealed cards go to hand", value: -looked.reduce(0) { $0 + context.keepValue($1) }),
            ModeOption(name: "trash the revealed cards", value: -Double(looked.count) * averageDeckKeepValue(context)),
        ]
        _ = context.chooseMode(options, chooser: context.rival) { mode, branch in
            if mode == 0 {
                for id in looked { branch.addToHand(id) }
            } else {
                branch.putInTrash(looked)
                branch.draw(2)
            }
        }
    }

    private func averageDeckKeepValue(_ reading: some GameReading) -> Double {
        let deck = reading.game.players[reading.owner].deck
        guard !deck.isEmpty else { return 0 }
        return deck.reduce(0) { $0 + reading.keepValue($1) } / Double(deck.count)
    }

    func playValue(in query: EffectQuery) -> Double? {
        query.deckCount() >= 2 ? 13 : nil
    }
}
