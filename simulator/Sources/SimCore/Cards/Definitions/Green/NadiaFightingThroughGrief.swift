struct NadiaFightingThroughGrief: GameCard {
    let data: CardData
    let listens: EventMask = []
    var modifierScopes: ModifierScopes { .itself }

    func modifiers(in query: EffectQuery) -> CardModifiers {
        guard query.subjectIsSelf, query.gigs(of: query.rival).count > query.gigs().count else { return .none }
        return .with { $0.keywords = .attacksGigsWhenPlayed }
    }

    func playValue(in query: EffectQuery) -> Double? {
        let behind = query.gigs(of: query.rival).count > query.gigs().count
        return standardPlayValue(in: query).map { $0 + (behind ? 10 : 0) }
    }
}
