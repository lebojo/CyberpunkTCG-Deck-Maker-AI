public struct Game: Sendable {
    public static let turnLimit = 60

    let catalog: CardCatalog
    var players: [Player]
    var rng: SplitMix64
    public internal(set) var active: Int
    public internal(set) var turn = 0
    public internal(set) var overtime = false
    var emptyFixerStreak = 0
    public internal(set) var outcome: Outcome = .ongoing
    var nextUid = 1
    var log: TraceLog?
    var tracing: Bool
    var skipReadyOnce = SidePair(false, false)
    var policies: SidePair<Policy>
    let scopesInPlay: ModifierScopes
    let listenersInPlay: EventMask
    let abilityTimingsInPlay: AbilityTimings

    public init(catalog: CardCatalog, decks: [DeckList], seed: UInt64, firstPlayer: Int, tracing: Bool, policies: [Policy] = [.greedy, .greedy]) {
        self.catalog = catalog
        self.policies = SidePair(policies)
        rng = SplitMix64(seed: seed)
        active = firstPlayer
        self.tracing = tracing
        log = tracing ? TraceLog() : nil
        let used = decks.flatMap(\.allCards)
        scopesInPlay = Game.scopes(of: used, in: catalog)
        listenersInPlay = Game.listeners(of: used, in: catalog)
        abilityTimingsInPlay = Set(used).reduce(into: AbilityTimings()) { $0.formUnion(catalog.profiles[$1].abilityTimings) }
        players = []
        for deck in decks {
            var main = deck.main
            main.shuffle(using: &rng)
            var legends = deck.legends.map { LegendSlot(cardId: $0) }
            legends.shuffle(using: &rng)
            var player = Player(deck: main, legends: legends)
            player.wantsMinGigs = deck.main.filter { catalog.stats[$0].mentionsMinGig }.count >= 6
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
        for slot in players[firstPlayer].legends.indices.prefix(2) { players[firstPlayer].legends[slot].spent = true }
        skipReadyOnce[firstPlayer] = true
    }

    init(scenarioWith catalog: CardCatalog, legends: [[Int]], decks: [[Int]], seed: UInt64 = 1, active: Int = 0) {
        self.catalog = catalog
        policies = SidePair(.greedy, .greedy)
        rng = SplitMix64(seed: seed)
        self.active = active
        tracing = false
        log = nil
        scopesInPlay = ModifierScopes(rawValue: .max)
        listenersInPlay = EventMask(rawValue: .max)
        abilityTimingsInPlay = AbilityTimings(rawValue: .max)
        players = (0..<2).map { side in
            Player(deck: decks[side], legends: legends[side].map { LegendSlot(cardId: $0) })
        }
    }

    init(placeholderFor catalog: CardCatalog) {
        self.catalog = catalog
        players = []
        rng = SplitMix64(seed: 0)
        active = 0
        tracing = false
        log = nil
        policies = SidePair(.greedy, .greedy)
        scopesInPlay = []
        listenersInPlay = []
        abilityTimingsInPlay = []
    }

    static func scopes(of ids: [Int], in catalog: CardCatalog) -> ModifierScopes {
        Set(ids).reduce(into: ModifierScopes()) { $0.formUnion(catalog.profiles[$1].scopes) }
    }

    static func listeners(of ids: [Int], in catalog: CardCatalog) -> EventMask {
        Set(ids).reduce(into: EventMask()) { $0.formUnion(catalog.profiles[$1].listens) }
    }

    func data(_ id: Int) -> CardData { catalog.data[id] }

    func stats(_ id: Int) -> CardStats { catalog.stats[id] }

    func profile(_ id: Int) -> CardProfile { catalog.profiles[id] }

    func implementation(_ id: Int) -> any GameCard { catalog.cards[id] }

    func name(_ id: Int) -> String { catalog.data[id].canonicalName }

    public var isOver: Bool {
        if case .ongoing = outcome { return false }
        return true
    }

    func note(_ message: @autoclosure () -> String) {
        if tracing, let log { log.lines.append(message()) }
    }

    var traceLines: [String] { log?.lines ?? [] }

    mutating func takeUid() -> Int {
        defer { nextUid += 1 }
        return nextUid
    }

    func unitIndex(_ p: Int, _ uid: Int) -> Int? {
        players[p].field.firstIndex { $0.uid == uid }
    }

    func unit(_ p: Int, _ uid: Int) -> FieldUnit? {
        unitIndex(p, uid).map { players[p].field[$0] }
    }

    func owner(ofUnit uid: Int) -> Int? {
        (0..<players.count).first { unitIndex($0, uid) != nil }
    }

    func allLegendsFaceUp(_ p: Int) -> Bool {
        players[p].legends.allSatisfy { $0.faceUp }
    }

    func faceUpLegendCount(_ p: Int) -> Int {
        players[p].legends.filter { $0.faceUp }.count
    }

    func wasUsedThisTurn(_ p: Int, key: Int) -> Bool {
        players[p].flags.usedOncePerTurn.contains(key)
    }

    mutating func markUsedThisTurn(_ p: Int, key: Int) {
        if !wasUsedThisTurn(p, key: key) { players[p].flags.usedOncePerTurn.append(key) }
    }
}
