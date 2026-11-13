struct MaxTacSuppressionTeam: GameCard {
    let data: CardData
    let listens: EventMask = []
    var modifierScopes: ModifierScopes { .rivalUnits }

    func modifiers(in query: EffectQuery) -> CardModifiers {
        guard let (subjectOwner, unit) = query.subjectUnit, subjectOwner != query.owner, unit.lagging else { return .none }
        return .with { $0.keywords = .cannotAttack }
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + 3 }
    }
}
