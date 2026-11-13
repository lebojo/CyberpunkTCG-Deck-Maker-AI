struct OverwatchPanamsGift: GameCard {
    let data: CardData
    let listens: EventMask = []
    var hints: AIHints { .with { $0.gearRemovalPriority = 5 } }

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Overwatch : discard to defeat a spent Unit", timing: .mainAction, eddieCost: 1)]
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        guard query.availableMana >= 1 else { return [] }
        let rival = query.rival
        return query.field(of: rival).compactMap { target in
            guard target.spent, let discard = cheapestDiscard(for: target, in: query) else { return nil }
            let value = 20 + query.unitThreat(target, owner: rival) - query.keepValue(discard) * 0.5
            return AbilityOption(ability: 0, target: .unit(owner: rival, uid: target.uid), value: value, eddieCost: 1)
        }
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard case .unit(let rival, let uid) = option.target, let target = context.unit(rival, uid), target.spent,
              let discard = cheapestDiscard(for: target, in: context), context.payEddies(1) else { return false }
        context.spendSelf()
        context.discard(discard)
        context.note("P\(context.owner) discards \(context.data(discard).name) to defeat \(context.data(target.cardId).name)")
        context.defeat(rival, uid: uid)
        return true
    }

    private func cheapestDiscard(for target: FieldUnit, in reading: some GameReading) -> Int? {
        let required = reading.stats(target.cardId).costValue
        return reading.hand()
            .filter { reading.stats($0).costValue >= required }
            .min { reading.keepValue($0) < reading.keepValue($1) }
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + 4 }
    }
}
