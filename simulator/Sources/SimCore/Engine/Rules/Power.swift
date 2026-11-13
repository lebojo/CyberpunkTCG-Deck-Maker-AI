extension Game {
    func power(_ owner: Int, _ unit: FieldUnit, attacking: Bool) -> Int {
        var total = stats(unit.cardId).power + unit.bonusPower
        if turn < unit.lingeringPowerUntil { total += unit.lingeringPower }
        for gear in unit.gears { total += stats(gear).power }
        let relevant = attacking ? ModifierScopes.unitScopes : ModifierScopes.staticUnitScopes
        if !scopesInPlay.isDisjoint(with: relevant) {
            total += unitModifiers(owner, unit, attacking: attacking).power
        }
        return max(0, total)
    }

    func legendPower(_ p: Int, slot: Int) -> Int {
        let legend = players[p].legends[slot]
        var total = stats(legend.cardId).power
        total += legend.gears.reduce(0) { $0 + stats($1).power }
        if profile(legend.cardId).scopes.contains(.itself) {
            let subject = QuerySubject.legend(owner: p, slot: slot)
            total += implementation(legend.cardId).modifiers(in: query(legend.cardId, owner: p, at: .legend(slot: slot), subject: subject)).power
        }
        return total
    }

    func needsUnitModifiers(_ unit: FieldUnit, attacking: Bool) -> Bool {
        if profile(unit.cardId).scopes.contains(.itself) { return true }
        if scopesInPlay.contains(.alliedUnits) || scopesInPlay.contains(.rivalUnits) { return true }
        if attacking && scopesInPlay.contains(.alliedAttackers) { return true }
        return scopesInPlay.contains(.equippedUnit) && unit.gears.contains { profile($0).scopes.contains(.equippedUnit) }
    }

    func unitModifiers(_ owner: Int, _ unit: FieldUnit, attacking: Bool) -> CardModifiers {
        var combined = CardModifiers()
        guard needsUnitModifiers(unit, attacking: attacking) else { return combined }
        let subject = QuerySubject.unit(owner: owner, uid: unit.uid)
        func absorb(_ cardId: Int, _ cardOwner: Int, _ location: CardLocation) {
            let found = implementation(cardId).modifiers(in: query(cardId, owner: cardOwner, at: location, subject: subject, attacking: attacking))
            combined.power += found.power
            combined.keywords.formUnion(found.keywords)
        }
        if profile(unit.cardId).scopes.contains(.itself) { absorb(unit.cardId, owner, .field(uid: unit.uid)) }
        if scopesInPlay.contains(.equippedUnit) {
            for gear in unit.gears where profile(gear).scopes.contains(.equippedUnit) { absorb(gear, owner, .gear(host: .unit(unit.uid))) }
        }
        if scopesInPlay.contains(.alliedUnits) {
            forEachCardInPlay(of: owner, with: .alliedUnits) { absorb($0, owner, $1) }
        }
        if attacking && scopesInPlay.contains(.alliedAttackers) {
            forEachCardInPlay(of: owner, with: .alliedAttackers) { absorb($0, owner, $1) }
        }
        if scopesInPlay.contains(.rivalUnits) {
            forEachCardInPlay(of: 1 - owner, with: .rivalUnits) { absorb($0, 1 - owner, $1) }
        }
        return combined
    }

    func forEachCardInPlay(of p: Int, with scope: ModifierScopes, _ body: (Int, CardLocation) -> Void) {
        for (slot, legend) in players[p].legends.enumerated() where legend.faceUp && profile(legend.cardId).scopes.contains(scope) {
            body(legend.cardId, .legend(slot: slot))
        }
        for unit in players[p].field {
            if profile(unit.cardId).scopes.contains(scope) { body(unit.cardId, .field(uid: unit.uid)) }
            for gear in unit.gears where profile(gear).scopes.contains(scope) { body(gear, .gear(host: .unit(unit.uid))) }
        }
        for (slot, legend) in players[p].legends.enumerated() where legend.faceUp {
            for gear in legend.gears where profile(gear).scopes.contains(scope) { body(gear, .gear(host: .legend(slot))) }
        }
    }

    func keywords(_ owner: Int, _ unit: FieldUnit) -> Keyword {
        var result = profile(unit.cardId).keywords.union(unit.grantedKeywords)
        for gear in unit.gears {
            result.formUnion(profile(gear).keywords.intersection(Keyword.grantedByGear))
        }
        if !scopesInPlay.isDisjoint(with: ModifierScopes.staticUnitScopes) {
            result.formUnion(unitModifiers(owner, unit, attacking: false).keywords)
        }
        return result
    }

    func isBlocker(_ owner: Int, _ unit: FieldUnit) -> Bool {
        keywords(owner, unit).contains(.blocker)
    }

    func hasAdrenaline(_ owner: Int, _ unit: FieldUnit) -> Bool {
        keywords(owner, unit).contains(.adrenaline)
    }

    func stealCount(forPower power: Int) -> Int {
        power >= 1 ? power / 10 + 1 : 0
    }

    func canAttackAtAll(_ owner: Int, _ unit: FieldUnit) -> Bool {
        if unit.spent { return false }
        if turn < unit.cannotAttackBefore { return false }
        let traits = keywords(owner, unit)
        if traits.contains(.cannotAttack) { return false }
        if unit.lagging && !traits.contains(.adrenaline) {
            if traits.contains(.attacksGigsWhenPlayed) && !players[1 - owner].gigs.isEmpty { return true }
            return traits.contains(.attacksUnitsWhenPlayed) && hasUnitTarget(owner)
        }
        return true
    }

    func hasUnitTarget(_ owner: Int) -> Bool {
        players[1 - owner].field.contains { $0.spent }
    }

    func canStealGigs(_ owner: Int, _ unit: FieldUnit) -> Bool {
        if players[1 - owner].gigs.isEmpty { return false }
        let traits = keywords(owner, unit)
        if unit.lagging && !traits.contains(.adrenaline) && !traits.contains(.attacksGigsWhenPlayed) { return false }
        return !traits.contains(.cannotStealGigs)
    }

    func validUnitTargets(_ owner: Int, _ attacker: FieldUnit) -> [FieldUnit] {
        let traits = keywords(owner, attacker)
        let hitsReady = traits.contains(.canAttackReadyUnits)
        let hitsBlockers = traits.contains(.canAttackReadyBlockers)
        return players[1 - owner].field.filter { $0.spent || hitsReady || (hitsBlockers && isBlocker(1 - owner, $0)) }
    }

    func isUnblockable(_ unit: FieldUnit, owner: Int) -> Bool {
        keywords(owner, unit).contains(.unblockable)
    }

    func attackersAvailable(_ owner: Int) -> [FieldUnit] {
        players[owner].field.filter { canAttackAtAll(owner, $0) }
    }
}
