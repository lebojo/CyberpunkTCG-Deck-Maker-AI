struct DumDumMaelstromTriggerman: GameCard {
    let data: CardData
    let listens: EventMask = .calledAsLegend
    var hints: AIHints { .with { $0.manaReluctance = 6 } }

    static let pumpBeforeAttack = 0
    static let pumpInFight = 1

    var abilities: [ActivatedAbility] {
        [
            ActivatedAbility(index: Self.pumpBeforeAttack, name: "Dum Dum : +1 par Gear avant l'attaque", timing: .beforeAttack, eddieCost: 1),
            ActivatedAbility(index: Self.pumpInFight, name: "Dum Dum : +1 par Gear en combat", timing: .fight, eddieCost: 1),
        ]
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .calledAsLegend = event, context.isAboutItself else { return }
        context.draw(defeatLowGear(&context) ? 2 : 1)
    }

    private func defeatLowGear(_ context: inout EffectContext) -> Bool {
        for unit in context.field() {
            if let gear = unit.gears.first(where: { context.stats($0).power <= 1 }) {
                context.defeatGear(GearTarget(owner: context.owner, host: .unit(unit.uid), gear: gear))
                return true
            }
        }
        for (slot, legend) in context.legends().enumerated() {
            if let gear = legend.gears.first(where: { context.stats($0).power <= 1 }) {
                context.defeatGear(GearTarget(owner: context.owner, host: .legend(slot), gear: gear))
                return true
            }
        }
        return false
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        guard query.availableMana >= 1 else { return [] }
        switch ability.index {
        case Self.pumpBeforeAttack:
            return beforeAttackOptions(query)
        default:
            guard let own = query.fightOwnUnit, own.isEquipped else { return [] }
            return [AbilityOption(ability: ability.index, target: .unit(owner: query.owner, uid: own.uid), eddieCost: 1, fight: .power(own: own.gears.count, other: 0))]
        }
    }

    private func beforeAttackOptions(_ query: EffectQuery) -> [AbilityOption] {
        guard let (attackerOwner, attacker) = query.subjectUnit, attackerOwner == query.owner, attacker.isEquipped else { return [] }
        let current = query.power(of: attacker, owner: attackerOwner, attacking: true)
        let boosted = current + attacker.gears.count
        let blockerPowers = query.field(of: query.rival).filter { !$0.spent && query.isBlocker($0, owner: query.rival) }.map { query.power(of: $0, owner: query.rival) }
        let crosses = query.stealCount(forPower: boosted) > query.stealCount(forPower: current)
        let beatsBlocker = blockerPowers.contains { $0 >= current && $0 < boosted }
        guard crosses || beatsBlocker else { return [] }
        return [AbilityOption(ability: Self.pumpBeforeAttack, target: .unit(owner: attackerOwner, uid: attacker.uid), eddieCost: 1)]
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard case .unit(let unitOwner, let uid) = option.target, let target = context.unit(unitOwner, uid), let slot = context.selfLegendSlot else { return false }
        let bonus = target.gears.count
        guard context.payEddies(1) else { return false }
        if option.ability == Self.pumpBeforeAttack || !context.legends()[slot].spent {
            context.spendLegend(slot: slot)
        }
        context.addPower(unitOwner, uid: uid, bonus)
        return true
    }
}
