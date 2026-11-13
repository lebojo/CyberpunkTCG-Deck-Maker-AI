struct JackieWellesRideOrDieChoom: GameCard {
    let data: CardData
    let listens: EventMask = [.attackDeclared, .defeated]

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard context.isAboutItself else { return }
        switch event {
        case .attackDeclared:
            guard let uid = context.selfUid else { return }
            context.addPower(context.owner, uid: uid, 2 * context.evenGigCount())
        case .defeated:
            context.draw(context.oddGigCount())
        default:
            break
        }
    }

    func attackValueBonus(in query: EffectQuery) -> Double { Double(2 * query.evenGigCount()) }

    func keepValue(in query: EffectQuery) -> Double {
        standardKeepValue(in: query) + Double(query.oddGigCount())
    }
}
