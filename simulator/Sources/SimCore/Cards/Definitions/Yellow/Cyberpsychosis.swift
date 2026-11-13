struct Cyberpsychosis: GameCard {
    let data: CardData
    let listens: EventMask = []

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Cyberpsychosis", timing: .beforeAttack, spendsSource: false)]
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        guard let (attackerOwner, attacker) = query.subjectUnit, attackerOwner == query.owner else { return [] }
        let gearCount = attacker.gears.count
        guard gearCount >= 2, query.canStealGigs(attacker, owner: attackerOwner) else { return [] }
        let boosted = query.power(of: attacker, owner: attackerOwner, attacking: true) + 3 * gearCount
        let steals = min(query.stealCount(forPower: boosted), query.gigs(of: query.rival).count)
        let cost = query.effectiveCost(query.cardId)
        guard query.gigs().count + steals >= 7, cost <= query.availableMana else { return [] }
        return [AbilityOption(ability: 0, target: .unit(owner: attackerOwner, uid: attacker.uid), eddieCost: cost)]
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard case .unit(let unitOwner, let uid) = option.target, let target = context.unit(unitOwner, uid) else { return false }
        guard context.playQuickFromHand(context.cardId) else { return false }
        context.addPower(unitOwner, uid: uid, 3 * target.gears.count)
        context.defeatAtEndOfTurn(unitOwner, uid: uid)
        return true
    }

    func playValue(in query: EffectQuery) -> Double? { nil }

    func keepValue(in query: EffectQuery) -> Double { 11 }
}
