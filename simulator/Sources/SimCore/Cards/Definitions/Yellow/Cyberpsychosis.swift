struct Cyberpsychosis: GameCard {
    let data: CardData
    let listens: EventMask = []

    private static let triggers: EventMask = [.stoleGigs, .wonFight, .lostFight]

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Cyberpsychosis", timing: .beforeAttack, spendsSource: false)]
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard context.isDelayedTrigger else { return }
        switch event {
        case .stoleGigs(let attackerUid, _):
            markForDefeat(attackerUid, in: &context)
        case .wonFight(let report), .lostFight(let report):
            markForDefeat(report.unitUid, in: &context)
        default:
            break
        }
    }

    private func markForDefeat(_ uid: Int, in context: inout EffectContext) {
        guard uid == context.delayedPayload else { return }
        context.defeatAtEndOfTurn(context.owner, uid: uid)
        context.consumeDelayedTrigger()
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
        context.registerDelayed(Self.triggers, expiry: .endOfTurn, payload: uid)
        return true
    }

    func playValue(in query: EffectQuery) -> Double? { nil }

    func keepValue(in query: EffectQuery) -> Double { 11 }
}
