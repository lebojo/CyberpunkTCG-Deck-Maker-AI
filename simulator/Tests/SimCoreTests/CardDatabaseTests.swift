import XCTest
@testable import SimCore

final class CardDatabaseTests: XCTestCase {
    func testEmbeddedDatabaseHasAllCardsWithUniqueKeys() throws {
        let cards = try CardDatabase.load()
        XCTAssertEqual(cards.count, 152)
        XCTAssertEqual(Set(cards.map(\.key)).count, cards.count)
    }

    func testRegistryKeysAllExistInDatabase() {
        for key in CardRegistry.standard.keys {
            XCTAssertNotNil(Fixtures.catalog.id(key: key), "clé enregistrée absente de cards.json : \(key)")
        }
    }

    func testKeywordsAreReadFromRulesText() {
        let catalog = Fixtures.catalog
        XCTAssertTrue(catalog.profiles[Fixtures.id("corpo-security")].keywords.contains([.blocker, .cannotAttack]))
        XCTAssertTrue(catalog.profiles[Fixtures.id("modded-kusanagi")].keywords.contains(.adrenaline))
        XCTAssertTrue(catalog.profiles[Fixtures.id("royce-psycho-on-the-edge")].keywords.contains(.goSolo))
        XCTAssertTrue(catalog.profiles[Fixtures.id("ruthless-lowlife")].keywords.contains(.cannotStealGigs))
        XCTAssertFalse(catalog.profiles[Fixtures.id("adrenaline-converter")].keywords.contains(.adrenaline))
    }

    func testFlavorOnlyTextsHaveNoEffect() {
        XCTAssertTrue(RulesText.isFlavorOnly("[Flavour Text] Takes a lot of juice to break bones like they do."))
        XCTAssertTrue(RulesText.isFlavorOnly("(Equip to a friendly Unit or face-up Legend.)\n\"One cut, one kill.\""))
        XCTAssertFalse(RulesText.isFlavorOnly("{Play} Draw 2."))
        XCTAssertEqual(CoverageReport.status(of: Fixtures.id("psycho-squad"), in: Fixtures.catalog), .flavorOnly)
    }

    func testIsolatedCopyKeepsIdentifiers() {
        let copy = Fixtures.catalog.isolatedCopy()
        XCTAssertEqual(copy.count, Fixtures.catalog.count)
        XCTAssertEqual(copy.id(key: "floor-it"), Fixtures.catalog.id(key: "floor-it"))
    }
}

final class DeckListTests: XCTestCase {
    func testParsesSiteExportWithDashesAndApostrophes() {
        let text = """
        # Name: Test Deck

        # Legends
        1x 036 Dum Dum — Maelstrom Triggerman
        1x 039 River Ward - Detective on the Hunt
        1x 004 Royce — Psycho on the Edge

        # Main Deck
        3x 053 Secondhand Bombus
        2x 065 Afterparty at Lizzie’s
        1x 999 Carte Inexistante
        """
        let deck = DeckList.parse(text: text, fallbackName: "fichier", catalog: Fixtures.catalog)
        XCTAssertEqual(deck.name, "Test Deck")
        XCTAssertEqual(deck.legends.count, 3)
        XCTAssertEqual(deck.main.count, 5)
        XCTAssertEqual(deck.main.filter { $0 == Fixtures.id("afterparty-at-lizzie-s") }.count, 2)
        XCTAssertTrue(deck.problems.contains("Carte inconnue : Carte Inexistante"))
    }

    func testRegressionDecksResolveCompletely() throws {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../Regression/decks").standardized
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasSuffix(".txt") }
        XCTAssertEqual(files.count, 5)
        for file in files {
            let deck = try DeckList.load(path: folder.appendingPathComponent(file).path, catalog: Fixtures.catalog)
            XCTAssertTrue(deck.problems.isEmpty, "\(file) : \(deck.problems)")
            XCTAssertTrue(CoverageReport.missingCards(in: [deck], catalog: Fixtures.catalog).isEmpty, file)
        }
    }
}
