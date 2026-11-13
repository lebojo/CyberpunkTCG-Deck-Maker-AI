struct SaulBrightStormrider: GameCard {
    let data: CardData
    let listens: EventMask = .endOfTurn
    var modifierScopes: ModifierScopes { .alliedAttackers }
    var hints: AIHints { .with { $0.threatBonus = 3 } }

    func modifiers(in query: EffectQuery) -> CardModifiers {
        guard !query.subjectIsSelf else { return .none }
        return .with { $0.power = 2 }
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .endOfTurn = event, context.selfUid != nil else { return }
        let owner = context.owner
        let spent = context.field().filter { $0.spent }.sorted { context.power(of: $0, owner: owner, attacking: true) > context.power(of: $1, owner: owner, attacking: true) }
        for unit in spent.prefix(3) { context.readyUnit(owner, uid: unit.uid) }
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + (query.field().count >= 2 ? 8 : 0) }
    }

    func keepValue(in query: EffectQuery) -> Double {
        standardKeepValue(in: query) + 4
    }
}
