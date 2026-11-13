import XCTest
@testable import SimCore

enum Fixtures {
    static let catalog: CardCatalog = {
        do { return try CardCatalog.embedded() } catch { fatalError("cards.json illisible : \(error)") }
    }()

    static func id(_ key: String, in catalog: CardCatalog = Fixtures.catalog) -> Int {
        guard let id = catalog.id(key: key) else { fatalError("clé inconnue : \(key)") }
        return id
    }

    static let filler = "corpo-security"

    static func game(
        catalog: CardCatalog = Fixtures.catalog,
        legends: [[String]] = [[], []],
        decks: [[String]] = [[], []],
        active: Int = 0,
        turn: Int = 1
    ) -> Game {
        let deckIds = decks.map { keys in (keys.isEmpty ? Array(repeating: filler, count: 10) : keys).map { id($0, in: catalog) } }
        var game = Game(scenarioWith: catalog, legends: legends.map { $0.map { id($0, in: catalog) } }, decks: deckIds, active: active)
        game.turn = turn
        return game
    }
}

extension Game {
    @discardableResult
    mutating func place(_ key: String, for p: Int, ready: Bool = true, gears: [String] = [], catalog: CardCatalog = Fixtures.catalog) -> Int {
        let uid = takeUid()
        var unit = FieldUnit(uid: uid, cardId: Fixtures.id(key, in: catalog), isLegend: false)
        unit.lagging = !ready
        unit.gears = gears.map { Fixtures.id($0, in: catalog) }
        players[p].field.append(unit)
        return uid
    }

    mutating func give(_ keys: [String], to p: Int, catalog: CardCatalog = Fixtures.catalog) {
        players[p].hand.append(contentsOf: keys.map { Fixtures.id($0, in: catalog) })
    }

    mutating func setGigs(_ gigs: [(sides: Int, value: Int)], for p: Int) {
        players[p].gigs = gigs.map { Gig(sides: $0.sides, value: $0.value) }
    }

    mutating func faceUp(_ p: Int, slot: Int) {
        players[p].legends[slot].faceUp = true
    }
}
