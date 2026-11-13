struct RogueAmendiaresPreemSolo: GameCard {
    let data: CardData
    let listens: EventMask = .gigStolen

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .gigStolen(let gig, let attackerUid) = event, context.unit(context.owner, attackerUid)?.isLegend == true else { return }
        if gig.isEven {
            context.draw(1)
        } else {
            context.discardWorst(context.rival)
        }
    }
}
