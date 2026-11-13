struct ZetatechBerserk: GameCard {
    let data: CardData
    let listens: EventMask = []
    var modifierScopes: ModifierScopes { .ownPlayCost }
    var hints: AIHints { .with { $0.gearRemovalPriority = 4 } }

    func modifiers(in query: EffectQuery) -> CardModifiers {
        .with {
            $0.costReduction = query.faceUpLegendCount()
            $0.costMinimum = 1
        }
    }
}
