struct SwordwiseHuscle: GameCard {
    let data: CardData
    let listens: EventMask = .attackDeclared

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .attackDeclared = event, context.isAboutItself, let unit = context.selfUnit else { return }
        if context.power(of: unit, owner: context.owner, attacking: true) >= 5 { context.draw(1) }
    }

    func attackValueBonus(in query: EffectQuery) -> Double {
        guard let unit = query.selfUnit else { return 0 }
        return query.power(of: unit, owner: query.owner, attacking: true) >= 5 ? 6 : 0
    }
}
