struct PepeNajarroWorkingDoubles: GameCard {
    let data: CardData
    let listens: EventMask = .attackDeclared
    var hints: AIHints { .with { $0.threatBonus = 3 } }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .attackDeclared = event, context.isAboutItself, context.valuePairs() >= 1 else { return }
        var readied = 0
        for (slot, legend) in context.legends().enumerated() where readied < 2 && legend.spent && legend.faceUp && context.data(legend.cardId).has(.merc) {
            context.readyLegend(slot: slot)
            readied += 1
        }
    }

    func keepValue(in query: EffectQuery) -> Double {
        standardKeepValue(in: query) + 4
    }
}
