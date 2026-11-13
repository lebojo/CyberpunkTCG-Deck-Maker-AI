struct FightJudgment: Sendable {
    let attackPower: Int
    let defendPower: Int
    let attackerWins: Bool
    let defenderWins: Bool
}

extension Game {
    func fightModifiers(_ owner: Int, _ fighter: FieldUnit, against other: FieldUnit) -> CardModifiers {
        guard scopesInPlay.contains(.fight) else { return CardModifiers() }
        var combined = CardModifiers()
        let subject = QuerySubject.fight(ownUid: fighter.uid, otherUid: other.uid)
        func absorb(_ cardId: Int, _ location: CardLocation) {
            guard profile(cardId).scopes.contains(.fight) else { return }
            let found = implementation(cardId).modifiers(in: query(cardId, owner: owner, at: location, subject: subject))
            combined.fightPower += found.fightPower
            combined.winsFight = combined.winsFight || found.winsFight
        }
        absorb(fighter.cardId, .field(uid: fighter.uid))
        for gear in fighter.gears { absorb(gear, .gear(host: .unit(fighter.uid))) }
        return combined
    }

    func judge(attackPower: Int, defendPower: Int, attackerOwner: Int, attackerUnit: FieldUnit, defenderUnit: FieldUnit) -> FightJudgment {
        let attackerMods = fightModifiers(attackerOwner, attackerUnit, against: defenderUnit)
        let defenderMods = fightModifiers(1 - attackerOwner, defenderUnit, against: attackerUnit)
        let attack = attackPower + attackerMods.fightPower
        let defend = defendPower + defenderMods.fightPower
        var attackerWins = attack > defend
        var defenderWins = defend > attack
        if attackerMods.winsFight { attackerWins = true; defenderWins = false }
        if defenderMods.winsFight { defenderWins = true; attackerWins = false }
        return FightJudgment(attackPower: attack, defendPower: defend, attackerWins: attackerWins, defenderWins: defenderWins)
    }

    func currentJudgment(attacker: Int, attackerUid: Int, defenderUid: Int, attackDelta: Int = 0, defendDelta: Int = 0) -> FightJudgment? {
        guard let attackerUnit = unit(attacker, attackerUid), let defenderUnit = unit(1 - attacker, defenderUid) else { return nil }
        return judge(
            attackPower: power(attacker, attackerUnit, attacking: true) + attackerUnit.fightBonus + attackDelta,
            defendPower: power(1 - attacker, defenderUnit, attacking: false) + defenderUnit.fightBonus + defendDelta,
            attackerOwner: attacker,
            attackerUnit: attackerUnit,
            defenderUnit: defenderUnit
        )
    }

    func fightScore(_ judgment: FightJudgment, side: Int, attacker: Int) -> Int {
        let wins = side == attacker ? judgment.attackerWins : judgment.defenderWins
        let rivalWins = side == attacker ? judgment.defenderWins : judgment.attackerWins
        if wins { return 2 }
        return rivalWins ? 0 : 1
    }
}
