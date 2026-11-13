struct ScrewLovelornFool: GameCard {
    let data: CardData
    let listens: EventMask = .defeated

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .defeated = event, context.isAboutItself else { return }
        let trash = context.trash()
        let ownPosition = trash.lastIndex(of: context.cardId)
        let options = trash.indices.filter { context.stats(trash[$0]).kind == .unit && $0 != ownPosition }
        guard let best = options.max(by: { context.stats(trash[$0]).costValue < context.stats(trash[$1]).costValue }),
              let recovered = context.takeFromTrash(at: best) else { return }
        context.addToHand(recovered)
    }
}
