struct NocturneOP55N1: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves
    var modifierScopes: ModifierScopes { .ownPlayCost }

    func modifiers(in query: EffectQuery) -> CardModifiers {
        query.fixerIsEmpty() ? .with { $0.costOverride = 1 } : .none
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        let rival = context.rival
        let threats = context.field(of: rival).filter { !$0.spent && context.power(of: $0, owner: rival, attacking: true) >= 6 }
        let behind = context.gigs(of: rival).count > context.gigs().count
        if behind, let target = threats.max(by: { context.power(of: $0, owner: rival, attacking: true) < context.power(of: $1, owner: rival, attacking: true) }) {
            context.forbidAttackUntilYourNextTurn(rival, uid: target.uid)
        } else {
            context.draw(2)
        }
    }

    func playValue(in query: EffectQuery) -> Double? {
        let base: Double = query.fixerIsEmpty() ? 22 : 14
        return base + (query.gigs(of: query.rival).count > query.gigs().count ? 4 : 0)
    }
}
