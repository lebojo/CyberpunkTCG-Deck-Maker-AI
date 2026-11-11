extension Game {
    func power(_ owner: Int, _ unit: FieldUnit, attacking: Bool) -> Int {
        let unitCard = card(unit.cardId)
        var total = unitCard.power + unit.bonusPower
        total += unit.gears.reduce(0) { $0 + card($1).power }
        if unitCard.behavior == .royce, active == owner { total += 2 * unit.gears.count }
        if attacking {
            if faceUpLegend(owner, .saburo), unitCard.isArasaka { total += 1 }
            let saulBoost = players[owner].field.contains { $0.uid != unit.uid && card($0.cardId).behavior == .saulBright }
            if saulBoost { total += 2 }
        }
        return max(0, total)
    }

    func isBlocker(_ unit: FieldUnit) -> Bool {
        switch card(unit.cardId).behavior {
        case .negotiators, .laLlorona, .corpoSecurity, .bombus, .meredith, .lizzyWizzy, .goroLegend:
            return true
        default:
            return unit.gears.contains { card($0).behavior == .mandibular }
        }
    }

    func hasAdrenaline(_ owner: Int, _ unit: FieldUnit) -> Bool {
        if card(unit.cardId).behavior == .kusanagi { return true }
        let converter = unit.gears.contains { card($0).behavior == .adrenalineConverter }
        return converter && players[1 - owner].gigs.count >= players[owner].gigs.count + 2
    }

    func stealCount(forPower power: Int) -> Int {
        power >= 1 ? power / 10 + 1 : 0
    }

    func canAttackAtAll(_ owner: Int, _ unit: FieldUnit) -> Bool {
        if unit.spent { return false }
        if turn < unit.cannotAttackBefore { return false }
        switch card(unit.cardId).behavior {
        case .corpoSecurity: return false
        case .voodooBoy: if players[owner].flags.programsPlayed == 0 { return false }
        default: break
        }
        if unit.lagging && !hasAdrenaline(owner, unit) { return card(unit.cardId).behavior == .oda && hasUnitTarget(owner) }
        return true
    }

    func hasUnitTarget(_ owner: Int) -> Bool {
        players[1 - owner].field.contains { $0.spent }
    }

    func canStealGigs(_ owner: Int, _ unit: FieldUnit) -> Bool {
        if players[1 - owner].gigs.isEmpty { return false }
        if unit.lagging && !hasAdrenaline(owner, unit) { return false }
        return card(unit.cardId).behavior != .ruthlessLowlife
    }

    func validUnitTargets(_ owner: Int, _ attacker: FieldUnit) -> [FieldUnit] {
        let canHitBlockers = card(attacker.cardId).behavior == .valentino && hasMoreStreetCred(owner)
        return players[1 - owner].field.filter { $0.spent || (canHitBlockers && isBlocker($0)) }
    }

    func attackersAvailable(_ owner: Int) -> [FieldUnit] {
        players[owner].field.filter { canAttackAtAll(owner, $0) }
    }
}
