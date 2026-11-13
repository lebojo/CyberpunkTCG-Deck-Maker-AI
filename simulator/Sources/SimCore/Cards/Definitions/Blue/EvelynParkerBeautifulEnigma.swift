struct EvelynParkerBeautifulEnigma: GameCard {
    let data: CardData
    let listens: EventMask = .stoleGigs
    var hints: AIHints { .with { $0.manaReluctance = 4 } }

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Evelyn : attaque forcée", timing: .mainAction, eddieCost: 1)]
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .stoleGigs(let attackerUid, _) = event, context.isAboutAlly,
              let attacker = context.unit(context.owner, attackerUid) else { return }
        let card = context.data(attacker.cardId)
        guard card.has(.corpo) || card.has(.ganger) else { return }
        context.readyEddies(1)
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        guard let target = forcedTarget(query), query.field().contains(where: { !$0.spent && query.isBlocker($0, owner: query.owner) }) else { return [] }
        return [AbilityOption(ability: 0, target: .unit(owner: query.rival, uid: target.uid), value: 6, eddieCost: 1)]
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard case .unit(let rival, let uid) = option.target, context.unit(rival, uid) != nil,
              let slot = context.selfLegendSlot, !context.legends()[slot].spent, context.payEddies(1) else { return false }
        context.spendLegend(slot: slot)
        context.forceAttackNextTurn(rival, uid: uid)
        return true
    }

    private func forcedTarget(_ reading: some GameReading) -> FieldUnit? {
        reading.bestRivalUnit { !$0.spent && reading.canAttack($0, owner: reading.rival) }
    }
}
