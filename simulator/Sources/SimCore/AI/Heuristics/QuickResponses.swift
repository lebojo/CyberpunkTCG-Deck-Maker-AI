extension Game {
    mutating func useStealReaction(defender: Int, attacker: Int, attackerUid: Int) -> Int {
        let subject = QuerySubject.attack(owner: attacker, uid: attackerUid)
        guard let use = firstAbilityUse(defender, timing: .rivalAttacksGigs, subject: subject) else { return 0 }
        guard activate(defender, use, subject: subject) else { return 0 }
        return use.option.stealReduction
    }

    mutating func useFightTricks(defender: Int, attacker: Int, attackerUid: Int, defenderUid: Int) {
        var side = defender
        var idleTurns = 0
        for _ in 0..<8 {
            let acted = tryFightTrick(side: side, attacker: attacker, attackerUid: attackerUid, defenderUid: defenderUid)
            idleTurns = acted ? 0 : idleTurns + 1
            if idleTurns >= 2 { return }
            side = 1 - side
        }
    }

    func fightTrickGain(_ preview: FightPreview, side: Int, attacker: Int, attackerUid: Int, defenderUid: Int, currentScore: Int) -> Int {
        switch preview {
        case .power(let own, let other):
            let attackDelta = side == attacker ? own : other
            let defendDelta = side == attacker ? other : own
            guard let after = currentJudgment(attacker: attacker, attackerUid: attackerUid, defenderUid: defenderUid, attackDelta: attackDelta, defendDelta: defendDelta) else { return 0 }
            return fightScore(after, side: side, attacker: attacker) - currentScore
        case .retaliation:
            return currentScore == 0 ? 1 : 0
        }
    }

    mutating func tryFightTrick(side: Int, attacker: Int, attackerUid: Int, defenderUid: Int) -> Bool {
        guard let before = currentJudgment(attacker: attacker, attackerUid: attackerUid, defenderUid: defenderUid) else { return false }
        let currentScore = fightScore(before, side: side, attacker: attacker)
        guard currentScore < 2 else { return false }
        let ownUid = side == attacker ? attackerUid : defenderUid
        let otherUid = side == attacker ? defenderUid : attackerUid
        let subject = QuerySubject.fight(ownUid: ownUid, otherUid: otherUid)
        var best: (use: AbilityUse, gain: Int, cost: Int)?
        for use in abilityUses(side, timing: .fight, subject: subject) {
            guard let preview = use.option.fight else { continue }
            let gain = fightTrickGain(preview, side: side, attacker: attacker, attackerUid: attackerUid, defenderUid: defenderUid, currentScore: currentScore)
            let cost = use.option.eddieCost
            if gain > 0, gain > (best?.gain ?? 0) || (gain == best?.gain && cost < (best?.cost ?? Int.max)) {
                best = (use, gain, cost)
            }
        }
        guard let choice = best else { return false }
        activate(side, choice.use, subject: subject)
        return true
    }
}
