struct GorillaArms: GameCard {
    let data: CardData
    let listens: EventMask = .stoleGigs

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .stoleGigs(let attackerUid, _) = event, context.isAboutHost else { return }
        let key = context.onceKey()
        guard !context.unitHasMark(context.owner, uid: attackerUid, key: key) else { return }
        context.markUnit(context.owner, uid: attackerUid, key: key)
        let thief = context.owner
        context.stealExtraGig(attackerUid: attackerUid) { game in
            let mine = Set(game.players[thief].gigs.map(\.value))
            return game.players[1 - thief].gigs.filter { !mine.contains($0.value) }.max { game.gigStealPriority(thief, $0) < game.gigStealPriority(thief, $1) }
        }
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + 4 }
    }
}
