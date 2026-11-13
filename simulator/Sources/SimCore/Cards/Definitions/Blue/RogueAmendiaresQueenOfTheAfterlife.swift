struct RogueAmendiaresQueenOfTheAfterlife: GameCard {
    let data: CardData
    let listens: EventMask = .gigStolen
    var hints: AIHints { .with { $0.threatBonus = 3 } }

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Rogue : affaiblir un Unit adverse", timing: .fight, eddieCost: 2)]
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .gigStolen(let gig, let attackerUid) = event, context.isAboutAlly,
              let attacker = context.unit(context.owner, attackerUid),
              gig.value < context.power(of: attacker, owner: context.owner, attacking: true),
              context.useOncePerTurn(context.onceKey()) else { return }
        context.readyEddies(2)
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        guard let unit = query.selfUnit, let opponent = query.fightOpponent, query.availableMana >= 2 else { return [] }
        let power = query.power(of: unit, owner: query.owner)
        guard power > 0 else { return [] }
        return [AbilityOption(ability: 0, target: .unit(owner: query.rival, uid: opponent.uid), eddieCost: 2, fight: .power(own: 0, other: -power))]
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard case .unit(let rival, let uid) = option.target, context.unit(rival, uid) != nil,
              let unit = context.selfUnit, !unit.spent, context.payEddies(2) else { return false }
        let power = context.power(of: unit, owner: context.owner)
        context.spendSelf()
        context.addPower(rival, uid: uid, -power)
        return true
    }
}
