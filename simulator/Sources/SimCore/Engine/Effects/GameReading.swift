public protocol GameReading {
    var game: Game { get }
    var owner: Int { get }
    var cardId: Int { get }
    var location: CardLocation { get }
    var subject: QuerySubject { get }
}

public extension GameReading {
    var rival: Int { 1 - owner }
    var card: CardData { game.data(cardId) }
    var turn: Int { game.turn }
    var isMyTurn: Bool { game.active == owner }

    var selfUid: Int? {
        if case .field(let uid) = location { return uid }
        return nil
    }

    var selfUnit: FieldUnit? { selfUid.flatMap { game.unit(owner, $0) } }

    var selfLegendSlot: Int? {
        if case .legend(let slot) = location { return slot }
        return nil
    }

    var host: EquipTarget? {
        if case .gear(let host) = location { return host }
        return nil
    }

    var hostUnit: FieldUnit? {
        if case .unit(let uid) = host { return game.unit(owner, uid) }
        return nil
    }

    func onceKey(_ index: Int = 0) -> Int { cardId * 16 + index }

    func data(_ id: Int) -> CardData { game.data(id) }
    func stats(_ id: Int) -> CardStats { game.stats(id) }

    func hand(of p: Int? = nil) -> [Int] { game.players[p ?? owner].hand }
    func trash(of p: Int? = nil) -> [Int] { game.players[p ?? owner].trash }
    func deckCount(of p: Int? = nil) -> Int { game.players[p ?? owner].deck.count }
    func field(of p: Int? = nil) -> [FieldUnit] { game.players[p ?? owner].field }
    func legends(of p: Int? = nil) -> [LegendSlot] { game.players[p ?? owner].legends }
    func gigs(of p: Int? = nil) -> [Gig] { game.players[p ?? owner].gigs }
    func fixerIsEmpty(of p: Int? = nil) -> Bool { game.players[p ?? owner].fixer.isEmpty }
    func unit(_ p: Int, _ uid: Int) -> FieldUnit? { game.unit(p, uid) }

    var wantsMinGigs: Bool { game.players[owner].wantsMinGigs }
    var programsPlayedThisTurn: Int { game.players[owner].flags.programsPlayed }
    var hasCalledThisTurn: Bool { game.players[owner].flags.called }
    var availableMana: Int { game.availableMana(owner) }
    func wasUsedThisTurn(_ key: Int) -> Bool { game.wasUsedThisTurn(owner, key: key) }

    func power(of unit: FieldUnit, owner unitOwner: Int, attacking: Bool = false) -> Int {
        game.power(unitOwner, unit, attacking: attacking)
    }

    func isBlocker(_ unit: FieldUnit, owner unitOwner: Int) -> Bool { game.isBlocker(unitOwner, unit) }
    func canAttack(_ unit: FieldUnit, owner unitOwner: Int) -> Bool { game.canAttackAtAll(unitOwner, unit) }
    func canStealGigs(_ unit: FieldUnit, owner unitOwner: Int) -> Bool { game.canStealGigs(unitOwner, unit) }
    func stealCount(forPower power: Int) -> Int { game.stealCount(forPower: power) }
    func effectiveCost(_ id: Int) -> Int { game.effectiveCost(owner, id) }

    func streetCred(of p: Int? = nil) -> Int? { game.streetCred(p ?? owner) }
    var hasMoreStreetCred: Bool { game.hasMoreStreetCred(owner) }
    var hasLessStreetCred: Bool { game.hasLessStreetCred(owner) }
    func valuePairs(of p: Int? = nil) -> Int { game.valuePairs(p ?? owner) }
    func minGigCount(of p: Int? = nil) -> Int { game.minGigCount(p ?? owner) }
    func maxGigCount(of p: Int? = nil) -> Int { game.maxGigCount(p ?? owner) }
    func distinctGigValues(of p: Int? = nil) -> Int { game.distinctGigValues(p ?? owner) }
    func hasGig(atLeast value: Int, of p: Int? = nil) -> Bool { game.hasGigAtLeast(p ?? owner, value) }
    func hasEvenAndOddGig(of p: Int? = nil) -> Bool { game.hasEvenAndOddGig(p ?? owner) }
    func evenGigCount(of p: Int? = nil) -> Int { gigs(of: p).filter(\.isEven).count }
    func oddGigCount(of p: Int? = nil) -> Int { gigs(of: p).filter { !$0.isEven }.count }
    func faceUpLegendCount(of p: Int? = nil) -> Int { game.faceUpLegendCount(p ?? owner) }
    func allLegendsFaceUp(of p: Int? = nil) -> Bool { game.allLegendsFaceUp(p ?? owner) }

    func keepValue(_ id: Int) -> Double { game.keepValue(owner, id) }
    func playValue(_ id: Int, from location: CardLocation = .hand) -> Double? { game.playValue(owner, id, from: location) }
    func unitThreat(_ unit: FieldUnit, owner unitOwner: Int) -> Double { game.unitThreat(unitOwner, unit) }
    func bestRivalUnit(where filter: (FieldUnit) -> Bool = { _ in true }) -> FieldUnit? { game.bestRivalUnit(owner, where: filter) }
    func worstRivalUnit(where filter: (FieldUnit) -> Bool = { _ in true }) -> FieldUnit? { game.worstRivalUnit(owner, where: filter) }
    func bestRivalGear(where filter: (Int) -> Bool = { _ in true }) -> GearTarget? { game.bestRivalGear(owner, where: filter) }
    func weakestUnit(of p: Int) -> FieldUnit? {
        game.players[p].field.min { game.unitThreat(p, $0) < game.unitThreat(p, $1) }
    }
    func bestAllyUnit(where filter: (FieldUnit) -> Bool = { _ in true }) -> FieldUnit? {
        game.players[owner].field.filter(filter).max { game.unitThreat(owner, $0) < game.unitThreat(owner, $1) }
    }
    func equipTarget(forGear id: Int) -> EquipTarget? { game.equipTarget(owner, gear: id) }
    func bestGigAdjustment(up: Int, down: Int) -> (index: Int, value: Int)? { game.bestAdjustment(owner, up: up, down: down) }
    func gigScore(_ gigs: [Gig], for p: Int? = nil) -> Double { game.gigScore(gigs, wantsMin: game.players[p ?? owner].wantsMinGigs) }
    func bestGigSwap(margin: Double) -> (mine: Int, theirs: Int)? { game.bestGigSwap(owner, margin: margin) }
    func bestMatchingGigSet() -> (index: Int, value: Int)? { game.bestMatchingSet(owner) }

    func hasDelayedTrigger(fromCard id: Int? = nil) -> Bool {
        game.players[owner].flags.delayedTriggers.contains { $0.sourceCardId == (id ?? cardId) }
    }

    var subjectUnit: (owner: Int, unit: FieldUnit)? {
        switch subject {
        case .unit(let p, let uid), .attack(let p, let uid):
            return game.unit(p, uid).map { (p, $0) }
        default:
            return nil
        }
    }

    var subjectIsSelf: Bool {
        if case .unit(let p, let uid) = subject { return p == owner && uid == selfUid }
        if case .legend(let p, let slot) = subject { return p == owner && slot == selfLegendSlot }
        return false
    }

    var subjectGearCount: Int {
        switch subject {
        case .unit(let p, let uid), .attack(let p, let uid): return game.unit(p, uid)?.gears.count ?? 0
        case .legend(let p, let slot): return game.players[p].legends.indices.contains(slot) ? game.players[p].legends[slot].gears.count : 0
        default: return 0
        }
    }

    var subjectCardId: Int? {
        switch subject {
        case .card(let id): return id
        case .unit(let p, let uid), .attack(let p, let uid): return game.unit(p, uid)?.cardId
        case .legend(let p, let slot): return game.players[p].legends.indices.contains(slot) ? game.players[p].legends[slot].cardId : nil
        case .fight(let uid, _): return game.unit(owner, uid)?.cardId
        case .none: return nil
        }
    }

    var fightOpponent: FieldUnit? {
        if case .fight(_, let other) = subject { return game.unit(rival, other) }
        return nil
    }

    var fightOwnUnit: FieldUnit? {
        if case .fight(let own, _) = subject { return game.unit(owner, own) }
        return nil
    }
}
