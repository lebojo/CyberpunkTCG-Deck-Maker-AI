final class TraceLog: @unchecked Sendable {
    var lines: [String] = []
}

struct Game: Sendable {
    static let turnLimit = 60

    let cards: [Card]
    var players: [Player]
    var rng: SplitMix64
    var active: Int
    var turn = 0
    var overtime = false
    var emptyFixerStreak = 0
    var outcome: Outcome = .ongoing
    var nextUid = 1
    let log: TraceLog
    var tracing: Bool
    var skipReadyOnce: [Bool] = [false, false]
    var searchPlayers: [Bool]

    init(catalog: CardCatalog, decks: [DeckList], seed: UInt64, firstPlayer: Int, tracing: Bool, search: [Bool] = [false, false]) {
        searchPlayers = search
        cards = catalog.cards
        rng = SplitMix64(seed: seed)
        active = firstPlayer
        self.tracing = tracing
        log = TraceLog()
        players = []
        for deck in decks {
            var main = deck.main
            main.shuffle(using: &rng)
            var legends = deck.legends.map { LegendSlot(cardId: $0) }
            legends.shuffle(using: &rng)
            var player = Player(deck: main, legends: legends)
            player.wantsMinGigs = deck.main.filter { catalog.cards[$0].mentionsMinGig }.count >= 6
            players.append(player)
        }
        for p in 0..<2 {
            draw(p, 6)
            if shouldMulligan(p) {
                players[p].mulliganed = true
                players[p].deck.append(contentsOf: players[p].hand)
                players[p].hand = []
                players[p].deck.shuffle(using: &rng)
                draw(p, 6)
            }
        }
        players[firstPlayer].legends[0].spent = true
        players[firstPlayer].legends[1].spent = true
        skipReadyOnce[firstPlayer] = true
    }

    func card(_ id: Int) -> Card { cards[id] }

    var isOver: Bool {
        if case .ongoing = outcome { return false }
        return true
    }

    func note(_ message: @autoclosure () -> String) {
        if tracing { log.lines.append(message()) }
    }

    func streetCred(_ p: Int) -> Int? {
        players[p].gigs.isEmpty ? nil : players[p].gigs.reduce(0) { $0 + $1.value }
    }

    func hasMoreStreetCred(_ p: Int) -> Bool {
        guard let mine = streetCred(p) else { return false }
        guard let theirs = streetCred(1 - p) else { return true }
        return mine > theirs
    }

    func hasLessStreetCred(_ p: Int) -> Bool {
        guard let theirs = streetCred(1 - p) else { return false }
        guard let mine = streetCred(p) else { return true }
        return mine < theirs
    }

    func valuePairs(_ p: Int) -> Int {
        Dictionary(grouping: players[p].gigs, by: { $0.value }).values.reduce(0) { $0 + $1.count / 2 }
    }

    func minGigCount(_ p: Int) -> Int {
        players[p].gigs.filter { $0.isMin }.count
    }

    func distinctGigValues(_ p: Int) -> Int {
        Set(players[p].gigs.map { $0.value }).count
    }

    func hasGigAtLeast(_ p: Int, _ value: Int) -> Bool {
        players[p].gigs.contains { $0.value >= value }
    }

    func unitIndex(_ p: Int, _ uid: Int) -> Int? {
        players[p].field.firstIndex { $0.uid == uid }
    }

    func faceUpLegend(_ p: Int, _ behavior: Behavior) -> Bool {
        players[p].legends.contains { $0.faceUp && card($0.cardId).behavior == behavior }
    }

    func fieldHas(_ p: Int, _ behavior: Behavior) -> Bool {
        players[p].field.contains { card($0.cardId).behavior == behavior }
    }

    func allLegendsFaceUp(_ p: Int) -> Bool {
        players[p].legends.allSatisfy { $0.faceUp }
    }

    func newUid() -> Int { nextUid }

    mutating func takeUid() -> Int {
        defer { nextUid += 1 }
        return nextUid
    }

    mutating func draw(_ p: Int, _ count: Int) {
        for _ in 0..<count {
            guard let top = players[p].deck.popLast() else {
                if !isOver { outcome = .win(player: 1 - p, reason: .deckOut) }
                return
            }
            players[p].hand.append(top)
        }
    }

    mutating func trashTop(_ p: Int, _ count: Int) -> [Int] {
        var taken: [Int] = []
        for _ in 0..<count {
            guard let top = players[p].deck.popLast() else { break }
            taken.append(top)
        }
        return taken
    }

    mutating func bottomDeck(_ p: Int, _ ids: [Int]) {
        var shuffled = ids
        shuffled.shuffle(using: &rng)
        players[p].deck.insert(contentsOf: shuffled, at: 0)
    }

    mutating func addToHand(_ p: Int, _ id: Int, revealed: Bool = true) {
        players[p].hand.append(id)
        if revealed { players[p].revealed.append(id) }
    }

    func knownHandCards(of p: Int) -> [Int] {
        var remaining = players[p].hand
        var known: [Int] = []
        for id in players[p].revealed {
            if let position = remaining.firstIndex(of: id) {
                remaining.remove(at: position)
                known.append(id)
            }
        }
        return known
    }

    var manaSources: [Int] { [0, 1] }

    func availableMana(_ p: Int) -> Int {
        players[p].eddiesReady + players[p].legends.filter { !$0.spent }.count
    }

    mutating func pay(_ p: Int, _ amount: Int) -> Bool {
        guard amount <= availableMana(p) else { return false }
        var remaining = amount
        let fromEddies = min(remaining, players[p].eddiesReady)
        players[p].eddiesReady -= fromEddies
        players[p].eddiesSpent += fromEddies
        remaining -= fromEddies
        while remaining > 0 {
            guard let slot = cheapestLegendToSpend(p) else { break }
            spendLegend(p, slot)
            remaining -= 1
        }
        return true
    }

    func cheapestLegendToSpend(_ p: Int) -> Int? {
        let candidates = players[p].legends.indices.filter { !players[p].legends[$0].spent }
        return candidates.min { legendSpendCost(p, $0) < legendSpendCost(p, $1) }
    }

    func legendSpendCost(_ p: Int, _ slot: Int) -> Int {
        let legend = players[p].legends[slot]
        if !legend.faceUp { return 0 }
        let gearBonus = legend.gears.contains { [.zetatech, .radioport].contains(card($0).behavior) } ? -2 : 0
        switch card(legend.cardId).behavior {
        case .riverWard, .dumDum, .hanako, .altSoulkiller: return 6 + gearBonus
        case .jackie, .saburo, .yorinobu: return 3 + gearBonus
        default: return 1 + gearBonus
        }
    }

    mutating func spendLegend(_ p: Int, _ slot: Int) {
        players[p].legends[slot].spent = true
        triggerSpent(p, equipped: players[p].legends[slot].gears, source: .legend(slot))
    }

    mutating func triggerSpent(_ p: Int, equipped gears: [Int], source: EquipTarget) {
        if !gears.isEmpty {
            for _ in 0..<players[p].field.filter({ card($0.cardId).behavior == .altMother }).count { draw(p, 1) }
        }
        for gear in gears {
            switch card(gear).behavior {
            case .zetatech:
                adjustGigBest(p, maxDelta: 1)
                if distinctGigValues(p) >= 3 && players[p].gigs.count >= 3 { draw(p, 1) }
            case .radioport:
                radioportCall(p)
            default:
                break
            }
        }
    }

    mutating func radioportCall(_ p: Int) {
        guard !players[p].flags.called,
              let slot = players[p].legends.indices.first(where: { index in
                  let legend = players[p].legends[index]
                  guard !legend.faceUp else { return false }
                  let legendCard = card(legend.cardId)
                  return legendCard.isArasaka || legendCard.text.contains("{Go Solo}")
              }) else { return }
        callLegend(p, slot, free: true)
    }

    mutating func callLegend(_ p: Int, _ slot: Int, free: Bool) {
        if !free {
            guard availableMana(p) >= 1, pay(p, 1) else { return }
        }
        players[p].flags.called = true
        players[p].legends[slot].faceUp = true
        let legendCard = card(players[p].legends[slot].cardId)
        note("P\(p) calls \(legendCard.name)")
        switch legendCard.behavior {
        case .dumDum:
            draw(p, sacrificeLowGear(p) ? 2 : 1)
        case .vStreetkid:
            let milled = trashTop(p, 3)
            players[p].trash.append(contentsOf: milled)
            if let pick = milled.first(where: { card($0).isBraindance && card($0).kind == .program }) {
                players[p].trash.removeAll { $0 == pick }
                addToHand(p, pick)
            }
        case .viktorSitDown:
            searchGears(p)
        default:
            break
        }
    }

    mutating func searchGears(_ p: Int) {
        var top: [Int] = []
        for _ in 0..<5 {
            guard let id = players[p].deck.popLast() else { break }
            top.append(id)
        }
        var rest: [Int] = []
        var taken = 0
        for id in top.sorted(by: { card($0).power > card($1).power }) {
            let candidate = card(id)
            if taken < 2, candidate.kind == .gear, candidate.costValue <= 2 {
                addToHand(p, id)
                taken += 1
            } else {
                rest.append(id)
            }
        }
        bottomDeck(p, rest)
    }

    mutating func sacrificeLowGear(_ p: Int) -> Bool {
        for index in players[p].field.indices {
            if let position = players[p].field[index].gears.firstIndex(where: { card($0).power <= 1 }) {
                players[p].trash.append(players[p].field[index].gears.remove(at: position))
                return true
            }
        }
        for slot in players[p].legends.indices {
            if let position = players[p].legends[slot].gears.firstIndex(where: { card($0).power <= 1 }) {
                players[p].trash.append(players[p].legends[slot].gears.remove(at: position))
                return true
            }
        }
        return false
    }

    mutating func defeat(_ owner: Int, uid: Int) {
        guard let index = unitIndex(owner, uid) else { return }
        let unit = players[owner].field.remove(at: index)
        players[owner].trash.append(contentsOf: unit.gears)
        let unitCard = card(unit.cardId)
        if !unit.isLegend { players[owner].trash.append(unit.cardId) }
        note("P\(owner) loses \(unitCard.name)")
        if !unit.gears.isEmpty, faceUpLegend(owner, .riverWard) {
            let looked = trashTop(owner, 2)
            if let worst = looked.min(by: { card($0).costValue < card($1).costValue }) {
                players[owner].trash.append(worst)
                for id in looked where id != worst { players[owner].deck.append(id) }
            } else {
                players[owner].deck.append(contentsOf: looked)
            }
        }
        if unit.gears.contains(where: { card($0).behavior == .relic }) {
            relicRevive(owner, defeatedCardId: unit.cardId, isLegend: unit.isLegend)
        }
        switch unitCard.behavior {
        case .screw:
            let selfPosition = players[owner].trash.lastIndex(of: unit.cardId)
            let options = players[owner].trash.enumerated().filter { card($0.element).kind == .unit && $0.offset != selfPosition }
            if let best = options.max(by: { card($0.element).costValue < card($1.element).costValue }) {
                let id = players[owner].trash.remove(at: best.offset)
                addToHand(owner, id)
            }
        case .dexter:
            if let mine = streetCred(owner), let theirs = streetCred(1 - owner), abs(mine - theirs) >= 10 {
                draw(owner, 2)
            } else if let mine = streetCred(owner), streetCred(1 - owner) == nil, mine >= 10 {
                draw(owner, 2)
            }
        default:
            break
        }
    }

    mutating func relicRevive(_ owner: Int, defeatedCardId: Int, isLegend: Bool) {
        let options = players[owner].trash.enumerated().filter { card($0.element).kind == .unit && card($0.element).costValue <= 9 }
        let defeatedPosition = players[owner].trash.lastIndex(of: defeatedCardId)
        let candidates = options.filter { isLegend || $0.offset != defeatedPosition }
        guard let best = candidates.max(by: { unitPlayValue(owner, card($0.element)) < unitPlayValue(owner, card($1.element)) }) else { return }
        let revived = players[owner].trash.remove(at: best.offset)
        let uid = takeUid()
        players[owner].field.append(FieldUnit(uid: uid, cardId: revived, isLegend: false))
        note("P\(owner) revives \(card(revived).name) with The Relic")
        if !isLegend, let position = players[owner].trash.lastIndex(of: defeatedCardId) {
            players[owner].trash.remove(at: position)
            bottomDeck(owner, [defeatedCardId])
        }
        onUnitPlayed(owner, uid: uid)
    }

    mutating func bottomDeckUnit(_ owner: Int, uid: Int) {
        guard let index = unitIndex(owner, uid) else { return }
        let unit = players[owner].field.remove(at: index)
        var moved = unit.gears
        if !unit.isLegend { moved.append(unit.cardId) }
        bottomDeck(owner, moved)
        note("P\(owner) has \(card(unit.cardId).name) bottom-decked")
    }

    mutating func spendUnit(_ owner: Int, uid: Int) {
        guard let index = unitIndex(owner, uid), !players[owner].field[index].spent else { return }
        players[owner].field[index].spent = true
        triggerSpent(owner, equipped: players[owner].field[index].gears, source: .unit(uid))
    }

    mutating func checkOvertimeWin() {
        guard overtime, !isOver else { return }
        let active = self.active
        let order = [active, 1 - active]
        let winners = order.filter { players[$0].gigs.count >= 7 }
        if winners.count == 2 { outcome = .draw }
        else if let winner = winners.first { outcome = .win(player: winner, reason: .gigsInOvertime) }
    }

    mutating func adjustGig(_ p: Int, index: Int, to value: Int) {
        guard players[p].gigs.indices.contains(index) else { return }
        let gig = players[p].gigs[index]
        guard value >= 1, value <= gig.sides, value != gig.value else { return }
        players[p].gigs[index].value = value
    }
}
