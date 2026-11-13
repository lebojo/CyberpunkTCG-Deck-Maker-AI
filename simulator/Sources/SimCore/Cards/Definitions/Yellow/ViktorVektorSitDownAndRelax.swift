struct ViktorVektorSitDownAndRelax: GameCard {
    let data: CardData
    let listens: EventMask = .calledAsLegend

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .calledAsLegend = event, context.isAboutItself else { return }
        let top = context.takeTop(5)
        var rest: [Int] = []
        var taken = 0
        for id in top.sorted(by: { context.stats($0).power > context.stats($1).power }) {
            if taken < 2, context.stats(id).kind == .gear, context.stats(id).costValue <= 2 {
                context.addToHand(id)
                taken += 1
            } else {
                rest.append(id)
            }
        }
        context.bottomDeck(rest)
    }
}
