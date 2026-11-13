struct FloorIt: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Floor It", timing: .fight, spendsSource: false)]
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        if let target = context.bestRivalUnit() {
            context.addPower(context.rival, uid: target.uid, -1)
        }
        context.draw(1)
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        let cost = query.effectiveCost(query.cardId)
        guard cost <= query.availableMana, let opponent = query.fightOpponent else { return [] }
        return [AbilityOption(ability: 0, target: .unit(owner: query.rival, uid: opponent.uid), eddieCost: cost, fight: .power(own: 0, other: -1))]
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard case .unit(let opponentOwner, let uid) = option.target, context.unit(opponentOwner, uid) != nil else { return false }
        guard context.playQuickFromHand(context.cardId) else { return false }
        context.addPower(opponentOwner, uid: uid, -1)
        context.draw(1)
        return true
    }

    func playValue(in query: EffectQuery) -> Double? {
        query.field(of: query.rival).isEmpty ? nil : 10
    }

    func keepValue(in query: EffectQuery) -> Double { 10 }
}
