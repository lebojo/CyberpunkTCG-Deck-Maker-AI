struct SynapseBurnout: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Synapse Burnout", timing: .fight, spendsSource: false)]
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        let legends = context.faceUpLegendCount()
        guard legends > 0 else { return }
        let owner = context.owner
        let candidates = context.field().filter { context.canAttack($0, owner: owner) }
        guard let best = candidates.max(by: { context.power(of: $0, owner: owner, attacking: true) < context.power(of: $1, owner: owner, attacking: true) }) else { return }
        context.addPower(owner, uid: best.uid, legends, .thisFight)
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        let cost = query.effectiveCost(query.cardId)
        let legends = query.faceUpLegendCount()
        guard cost <= query.availableMana, legends > 0, let own = query.fightOwnUnit else { return [] }
        return [AbilityOption(ability: 0, target: .unit(owner: query.owner, uid: own.uid), eddieCost: cost, fight: .power(own: legends, other: 0))]
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard case .unit(let unitOwner, let uid) = option.target, context.unit(unitOwner, uid) != nil,
              case .power(let bonus, _) = option.fight else { return false }
        guard context.playQuickFromHand(context.cardId) else { return false }
        context.addPower(unitOwner, uid: uid, bonus, .thisFight)
        return true
    }

    func playValue(in query: EffectQuery) -> Double? {
        let legends = query.faceUpLegendCount()
        let owner = query.owner
        guard legends > 0, query.field(of: query.rival).contains(where: { $0.spent }),
              query.field().contains(where: { query.canAttack($0, owner: owner) }) else { return nil }
        return 12 + Double(legends) * 4
    }
}
