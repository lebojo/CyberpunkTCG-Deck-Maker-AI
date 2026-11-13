struct KerryEurodyneAxeAttitudeAudience: GameCard {
    let data: CardData
    let listens: EventMask = .gigRolled
    var hints: AIHints { .with { $0.manaReluctance = 2 } }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .gigRolled(let index) = event, context.gigs().indices.contains(index) else { return }
        drawForExtremeRoll(&context, index: index)
        guard shouldReroll(context, index: index) else { return }
        context.note("P\(context.owner) rerolls a Gig with Kerry Eurodyne")
        context.rerollGig(index: index)
        drawForExtremeRoll(&context, index: index)
    }

    private func drawForExtremeRoll(_ context: inout EffectContext, index: Int) {
        let gig = context.gigs()[index]
        guard gig.isMin || gig.isMax else { return }
        context.draw(gig.sides == 20 ? 3 : 1)
    }

    private func shouldReroll(_ context: EffectContext, index: Int) -> Bool {
        let gig = context.gigs()[index]
        let score = context.wantsMinGigs ? gig.sides + 1 - gig.value : gig.value
        return score * 2 < gig.sides + 1
    }
}
