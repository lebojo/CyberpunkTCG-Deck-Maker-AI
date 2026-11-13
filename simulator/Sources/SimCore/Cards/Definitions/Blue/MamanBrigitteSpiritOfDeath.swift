struct MamanBrigitteSpiritOfDeath: GameCard {
    let data: CardData
    let listens: EventMask = .played

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .played = event, context.isAboutItself else { return }
        let hand = context.hand()
        let programs = hand.indices.filter { context.stats(hand[$0]).kind == .program }
            .sorted { context.keepValue(hand[$0]) < context.keepValue(hand[$1]) }
        guard programs.count >= 2,
              context.keepValue(hand[programs[0]]) + context.keepValue(hand[programs[1]]) < 20,
              let target = context.bestRivalUnit(where: { !$0.isEquipped }) else { return }
        for index in programs.prefix(2).sorted(by: >) { context.discard(atHandIndex: index) }
        context.bottomDeckUnit(context.rival, uid: target.uid)
    }

    func playValue(in query: EffectQuery) -> Double? {
        let programs = query.hand().filter { query.stats($0).kind == .program }.count
        let hasTarget = query.field(of: query.rival).contains { !$0.isEquipped }
        return standardPlayValue(in: query).map { $0 + (programs >= 2 && hasTarget ? 8 : 0) }
    }
}
