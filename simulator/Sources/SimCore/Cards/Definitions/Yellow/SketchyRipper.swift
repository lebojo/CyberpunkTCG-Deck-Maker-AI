struct SketchyRipper: GameCard {
    let data: CardData
    let listens: EventMask = .attackDeclared

    var hints: AIHints {
        .with {
            $0.prefersNoGears = true
            $0.attackWithoutStealValue = 6
        }
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .attackDeclared = event, context.isAboutItself else { return }
        var rest = context.takeTop(3)
        let pick = rest.filter { context.stats($0).kind == .gear }.max { context.keepValue($0) < context.keepValue($1) }
        if let pick, let position = rest.firstIndex(of: pick) {
            rest.remove(at: position)
            context.addToHand(pick)
        }
        context.bottomDeck(rest)
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 - 2 }
    }

    func attackValueBonus(in query: EffectQuery) -> Double { 10 }
}
