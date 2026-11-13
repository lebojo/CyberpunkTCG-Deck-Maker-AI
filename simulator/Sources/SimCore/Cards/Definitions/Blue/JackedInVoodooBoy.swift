struct JackedInVoodooBoy: GameCard {
    let data: CardData
    let listens: EventMask = []
    var modifierScopes: ModifierScopes { .itself }

    func modifiers(in query: EffectQuery) -> CardModifiers {
        guard query.subjectIsSelf, query.programsPlayedThisTurn == 0 else { return .none }
        return .with { $0.keywords = .cannotAttack }
    }

    func playValue(in query: EffectQuery) -> Double? {
        let hasProgram = query.hand().contains { query.stats($0).kind == .program }
        let fuelled = hasProgram || query.programsPlayedThisTurn > 0
        return standardPlayValue(in: query).map { $0 + (fuelled ? 4 : -6) }
    }

    func keepValue(in query: EffectQuery) -> Double {
        standardKeepValue(in: query) - 2
    }
}
