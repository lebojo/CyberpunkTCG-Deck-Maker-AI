struct VStreetkid: GameCard {
    let data: CardData
    let listens: EventMask = .calledAsLegend

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .calledAsLegend = event, context.isAboutItself else { return }
        let milled = context.trashTop(3)
        guard let pick = milled.first(where: { context.data($0).has(.braindance) && context.stats($0).kind == .program }) else { return }
        while context.takeLastFromTrash(pick) {}
        context.addToHand(pick)
    }
}
