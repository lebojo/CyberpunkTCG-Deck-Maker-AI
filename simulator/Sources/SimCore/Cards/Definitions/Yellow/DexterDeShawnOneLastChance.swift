struct DexterDeShawnOneLastChance: GameCard {
    let data: CardData
    let listens: EventMask = [.played, .attackDeclared, .defeated]

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard context.isAboutItself else { return }
        switch event {
        case .played, .attackDeclared:
            context.adjustGigBest(by: 1)
        case .defeated:
            if streetCredGapIsWide(context) { context.draw(2) }
        default:
            break
        }
    }

    private func streetCredGapIsWide(_ context: EffectContext) -> Bool {
        guard let mine = context.streetCred() else { return false }
        guard let theirs = context.streetCred(of: context.rival) else { return mine >= 10 }
        return abs(mine - theirs) >= 10
    }
}
