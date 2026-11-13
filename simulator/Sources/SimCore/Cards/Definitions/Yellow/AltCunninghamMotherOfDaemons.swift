struct AltCunninghamMotherOfDaemons: GameCard {
    let data: CardData
    let listens: EventMask = [.becameSpent, .gigWouldBeStolen]

    func action(_ event: GameEvent, in context: inout EffectContext) {
        switch event {
        case .becameSpent(_, let isEquipped) where isEquipped:
            context.draw(1)
        case .gigWouldBeStolen(let gig, _):
            guard let discarded = context.hand().first(where: { context.stats($0).costValue == gig.value }) else { return }
            context.discard(discarded)
            context.prevent()
        default:
            break
        }
    }
}
