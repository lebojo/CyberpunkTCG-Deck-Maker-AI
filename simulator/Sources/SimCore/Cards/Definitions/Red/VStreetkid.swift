struct VStreetkid: GameCard {
    let data: CardData
    let listens: EventMask = .calledAsLegend

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .calledAsLegend = event, context.isAboutItself else { return }
        _ = context.trashTop(3)
        let braindancePrograms = context.trash().filter { context.data($0).has(.braindance) && context.stats($0).kind == .program }
        guard let pick = braindancePrograms.max(by: { context.keepValue($0) < context.keepValue($1) }),
              context.takeLastFromTrash(pick) else { return }
        context.addToHand(pick)
    }
}
