struct RiotShield: GameCard {
    let data: CardData
    let listens: EventMask = []
    var modifierScopes: ModifierScopes { .goSoloCost }
    var hints: AIHints { .with { $0.gearRemovalPriority = 3 } }

    static let goSoloSurcharge = 2

    func modifiers(in query: EffectQuery) -> CardModifiers {
        guard case .legend(let legendOwner, _) = query.subject, legendOwner != query.owner else { return .none }
        return .with { $0.goSoloCostChange = Self.goSoloSurcharge }
    }
}
