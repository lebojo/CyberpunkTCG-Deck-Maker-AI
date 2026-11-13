struct JohnnySilverhandNeverStopFighting: GameCard {
    let data: CardData
    let listens: EventMask = .wonFight
    var modifierScopes: ModifierScopes { .fight }

    func modifiers(in query: EffectQuery) -> CardModifiers {
        guard let opponent = query.fightOpponent, query.data(opponent.cardId).has(.corpo) else { return .none }
        return .with { $0.winsFight = true }
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .wonFight = event, context.isAboutItself, let uid = context.selfUid else { return }
        let key = context.onceKey()
        guard !context.unitHasMark(context.owner, uid: uid, key: key) else { return }
        context.readyUnit(context.owner, uid: uid)
        context.markUnit(context.owner, uid: uid, key: key)
    }
}
