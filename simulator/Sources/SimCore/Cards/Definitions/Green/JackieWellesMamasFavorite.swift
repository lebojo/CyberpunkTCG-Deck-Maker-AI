struct JackieWellesMamasFavorite: GameCard {
    let data: CardData
    let listens: EventMask = .wouldBeDefeated

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .wouldBeDefeated(let uid, _) = event, context.isAboutAlly,
              let jackieUid = context.selfUid, let jackie = context.selfUnit,
              let saved = context.unit(context.owner, uid),
              context.availableMana >= 1, isWorthSaving(saved, over: jackie, context) else { return }
        guard context.payEddies(1) else { return }
        context.note("P\(context.owner) defeats \(context.card.name) instead of \(context.data(saved.cardId).name)")
        context.prevent()
        context.defeat(context.owner, uid: jackieUid)
    }

    private func isWorthSaving(_ saved: FieldUnit, over jackie: FieldUnit, _ context: EffectContext) -> Bool {
        let owner = context.owner
        return context.unitThreat(saved, owner: owner) >= context.unitThreat(jackie, owner: owner) * 0.6
    }
}
