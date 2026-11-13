struct RoycePsychoOnTheEdge: GameCard {
    let data: CardData
    let listens: EventMask = []
    var modifierScopes: ModifierScopes { .itself }

    var hints: AIHints {
        .with {
            $0.extraPowerPerGear = 2
            $0.carriesGearsAsLegend = true
        }
    }

    func modifiers(in query: EffectQuery) -> CardModifiers {
        guard query.subjectIsSelf, query.isMyTurn else { return .none }
        return .with { $0.power = 2 * query.subjectGearCount }
    }
}
