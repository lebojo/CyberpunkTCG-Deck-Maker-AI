struct MuamarReyesElCapitan: GameCard {
    let data: CardData
    let listens: EventMask = .calledAsLegend
    var hints: AIHints { .with { $0.manaReluctance = 3 } }

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Muamar Reyes : ajuster un Gig de 1", timing: .mainAction)]
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        switch event {
        case .calledAsLegend where context.isAboutItself:
            chooseCallEffect(&context)
        case .wouldBeDefeated(let uid, let cause) where context.isDelayedTrigger:
            guard case .fight = cause, uid == context.delayedPayload else { return }
            context.prevent()
        default:
            break
        }
    }

    private func chooseCallEffect(_ context: inout EffectContext) {
        let protected = unitAtRisk(context)
        let value = protected.map { context.unitThreat($0, owner: context.owner) / 2 } ?? 1
        let options = [ModeOption(name: "protect a friendly Unit in fights", value: value), ModeOption(name: "draw 1", value: ModeOption.drawOne)]
        _ = context.chooseMode(options) { mode, branch in
            if mode == 0 { protect(protected ?? branch.bestAllyUnit(), &branch) } else { branch.draw(1) }
        }
    }

    private func unitAtRisk(_ reading: some GameReading) -> FieldUnit? {
        let owner = reading.owner
        let rival = reading.rival
        return reading.bestAllyUnit { ally in
            guard reading.canAttack(ally, owner: owner) else { return false }
            let attack = reading.power(of: ally, owner: owner, attacking: true)
            return reading.fightableRivalUnits(for: ally).contains { reading.power(of: $0, owner: rival) >= attack }
        }
    }

    private func protect(_ unit: FieldUnit?, _ context: inout EffectContext) {
        guard let unit else { return }
        context.registerDelayed(.wouldBeDefeated, expiry: .endOfTurn, charges: 1, payload: unit.uid)
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        guard query.bestGigAdjustment(up: 1, down: 1) != nil else { return [] }
        return [AbilityOption(ability: 0, value: 7)]
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard context.adjustGigBest(by: 1) else { return false }
        context.spendSelf()
        return true
    }
}
