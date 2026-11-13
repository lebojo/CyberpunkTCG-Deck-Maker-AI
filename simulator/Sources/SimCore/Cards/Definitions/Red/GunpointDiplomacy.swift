struct GunpointDiplomacy: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    private static let attackReadyUnits = 0
    private static let gainPower = 1

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event, let target = target(context) else { return }
        let uid = target.uid
        if context.hasLessStreetCred {
            _ = context.chooseMode(2, chooser: context.rival) { mode, branch in apply(mode, to: uid, &branch) }
        } else {
            apply(Self.attackReadyUnits, to: uid, &context)
            apply(Self.gainPower, to: uid, &context)
        }
    }

    private func apply(_ effect: Int, to uid: Int, _ context: inout EffectContext) {
        if effect == Self.attackReadyUnits {
            context.grantKeyword(.canAttackReadyUnits, to: context.owner, uid: uid)
        } else {
            context.addPower(context.owner, uid: uid, 3)
        }
    }

    private func target(_ reading: some GameReading) -> FieldUnit? {
        let owner = reading.owner
        return reading.bestAllyUnit { reading.canAttack($0, owner: owner) } ?? reading.bestAllyUnit()
    }

    func playValue(in query: EffectQuery) -> Double? {
        let owner = query.owner
        guard query.field().contains(where: { query.canAttack($0, owner: owner) }) else { return nil }
        let rivalHasReadyUnits = query.field(of: query.rival).contains { !$0.spent }
        return (query.hasLessStreetCred ? 10 : 16) + (rivalHasReadyUnits ? 4 : 0)
    }
}
