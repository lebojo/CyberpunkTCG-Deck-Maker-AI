public struct FightSwing: Sendable {
    public let ally: FieldUnit
    public let rival: FieldUnit
    public let value: Double
}

extension GameReading {
    func bestFightSwing(allyBonus: Int, rivalMalus: Int) -> FightSwing? {
        var best: FightSwing?
        for ally in field() where canAttack(ally, owner: owner) {
            let attack = power(of: ally, owner: owner, attacking: true)
            for target in fightableRivalUnits(for: ally) {
                let defense = power(of: target, owner: rival)
                guard attack <= defense, attack + allyBonus > defense - rivalMalus else { continue }
                let value = unitThreat(target, owner: rival) + ModeOption.drawOne
                if value > (best?.value ?? -Double.infinity) { best = FightSwing(ally: ally, rival: target, value: value) }
            }
        }
        return best
    }

    func fightableRivalUnits(for ally: FieldUnit) -> [FieldUnit] {
        let targets = game.validUnitTargets(owner, ally)
        let blockers = field(of: rival).filter { blocker in
            !blocker.spent && isBlocker(blocker, owner: rival) && !targets.contains { $0.uid == blocker.uid }
        }
        return targets + blockers
    }
}
