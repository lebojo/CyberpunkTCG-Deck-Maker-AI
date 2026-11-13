struct PlacideVoodooSentinel: GameCard {
    let data: CardData
    let listens: EventMask = [.played, .attackDeclared]

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard context.isAboutItself else { return }
        switch event {
        case .played, .attackDeclared:
            discardProgramToBottomDeck(&context)
        default:
            break
        }
    }

    private func discardProgramToBottomDeck(_ context: inout EffectContext) {
        let hand = context.hand()
        guard let target = context.bestRivalUnit(),
              let discardIndex = hand.indices.filter({ context.stats(hand[$0]).kind == .program })
                .min(by: { context.keepValue(hand[$0]) < context.keepValue(hand[$1]) }),
              context.keepValue(hand[discardIndex]) < 14 else { return }
        context.discard(atHandIndex: discardIndex)
        context.bottomDeckUnit(context.rival, uid: target.uid)
    }
}
