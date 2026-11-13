struct DelamainCab: GameCard {
    let data: CardData
    let listens: EventMask = [.stoleGigs, .endOfTurn]

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard let uid = context.selfUid else { return }
        switch event {
        case .stoleGigs where context.isAboutItself:
            context.markUnit(context.owner, uid: uid, key: context.onceKey())
        case .endOfTurn where context.unitHasMark(context.owner, uid: uid, key: context.onceKey()):
            context.readyEddies(1)
        default:
            break
        }
    }

    func attackValueBonus(in query: EffectQuery) -> Double { 3 }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + 2 }
    }
}
