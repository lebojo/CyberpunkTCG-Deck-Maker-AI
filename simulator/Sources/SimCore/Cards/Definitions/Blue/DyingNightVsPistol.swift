struct DyingNightVsPistol: GameCard {
    let data: CardData
    let listens: EventMask = [.attackDeclared, .endOfTurn]

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard context.isAboutHost else { return }
        switch event {
        case .attackDeclared:
            context.decreaseGigBest(by: 2)
        case .endOfTurn where hostIsNamedV(context):
            context.readyEddies(2)
        default:
            break
        }
    }

    private func hostIsNamedV(_ context: EffectContext) -> Bool {
        guard let host = context.hostUnit else { return false }
        return context.data(host.cardId).name == "V"
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + 2 }
    }
}
