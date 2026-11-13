struct YorinobuArasakaSteelDragon: GameCard {
    let data: CardData
    let listens: EventMask = [.played, .defeated]

    private static let maxFreeCost = 4

    func action(_ event: GameEvent, in context: inout EffectContext) {
        switch event {
        case .played where context.isAboutItself:
            playFreeUnit(&context)
        case .defeated(let report):
            drawForArasakaDefeat(report, &context)
        default:
            break
        }
    }

    private func playFreeUnit(_ context: inout EffectContext) {
        let fromHand = context.hand().filter { isCandidate($0, context) }.map { (id: $0, fromTrash: false) }
        let fromTrash = context.trash().filter { isCandidate($0, context) }.map { (id: $0, fromTrash: true) }
        let valued = (fromHand + fromTrash).compactMap { choice in value(of: choice, context).map { (choice: choice, value: $0) } }
        guard let best = valued.max(by: { $0.value < $1.value }), let uid = enter(best.choice, &context) else { return }
        let choice = best.choice
        context.grantKeyword(.attacksUnitsWhenPlayed, to: context.owner, uid: uid)
        context.note("P\(context.owner) plays \(context.data(choice.id).canonicalName) for free")
    }

    private func isCandidate(_ id: Int, _ reading: some GameReading) -> Bool {
        reading.stats(id).kind == .unit && reading.stats(id).costValue <= Self.maxFreeCost
    }

    private func value(of choice: (id: Int, fromTrash: Bool), _ reading: some GameReading) -> Double? {
        reading.playValue(choice.id, from: choice.fromTrash ? .trash : .hand)
    }

    private func enter(_ choice: (id: Int, fromTrash: Bool), _ context: inout EffectContext) -> Int? {
        if choice.fromTrash {
            guard context.takeLastFromTrash(choice.id) else { return nil }
            return context.putUnitIntoPlay(choice.id)
        }
        guard context.playFromHand(choice.id, free: true) else { return nil }
        return context.field().last { $0.cardId == choice.id }?.uid
    }

    private func drawForArasakaDefeat(_ report: DefeatedUnit, _ context: inout EffectContext) {
        guard let uid = context.selfUid, context.data(report.cardId).has(.arasaka) else { return }
        let key = context.onceKey()
        guard !context.unitHasMark(context.owner, uid: uid, key: key) else { return }
        context.markUnit(context.owner, uid: uid, key: key)
        context.draw(1)
    }

    func playValue(in query: EffectQuery) -> Double? {
        let hasFreeUnit = (query.hand() + query.trash()).contains { isCandidate($0, query) }
        return standardPlayValue(in: query).map { $0 + (hasFreeUnit ? 10 : 0) }
    }
}
