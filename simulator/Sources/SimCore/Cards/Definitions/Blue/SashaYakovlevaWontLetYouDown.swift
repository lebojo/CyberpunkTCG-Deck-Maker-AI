struct SashaYakovlevaWontLetYouDown: GameCard {
    let data: CardData
    let listens: EventMask = [.attackDeclared, .defeated]
    var modifierScopes: ModifierScopes { .itself }

    var hints: AIHints {
        .with {
            $0.attackWithoutStealValue = 45
            $0.goSoloBonus = 4
        }
    }

    func modifiers(in query: EffectQuery) -> CardModifiers {
        guard case .legend = query.subject else { return .none }
        return .with { $0.power = 8 }
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard context.isAboutItself else { return }
        switch event {
        case .attackDeclared:
            revealTopAndPump(&context)
        case .defeated:
            context.discardWorst(context.rival)
        default:
            break
        }
    }

    private func revealTopAndPump(_ context: inout EffectContext) {
        guard let uid = context.selfUid, let top = context.takeTop(1).first else { return }
        context.addToHand(top)
        context.addPower(context.owner, uid: uid, context.stats(top).costValue)
    }
}
