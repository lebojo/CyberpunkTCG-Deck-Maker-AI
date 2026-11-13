import XCTest
@testable import SimCore

struct DeathWardTestCard: GameCard {
    let data: CardData
    let listens: EventMask = .wouldBeDefeated

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .wouldBeDefeated = event, context.isAboutItself, context.useOncePerTurn(context.onceKey()) else { return }
        context.prevent()
    }
}

struct ModeTestCard: GameCard {
    let data: CardData
    let listens: EventMask = .programResolves

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .programResolves = event else { return }
        _ = context.chooseMode(2) { mode, branch in
            if mode == 0 { branch.draw(2) } else { branch.readyEddies(1) }
        }
    }
}

final class EffectAPITests: XCTestCase {
    func catalog(with overrides: [String: CardRegistry.Factory]) -> CardCatalog {
        let base = CardRegistry.standard
        let factories = Dictionary(uniqueKeysWithValues: base.keys.map { key in (key, base.factories[key]!) })
            .merging(overrides) { _, override in override }
        return CardCatalog(data: Fixtures.catalog.data, registry: CardRegistry(factories: factories))
    }

    func testReplacementEffectPreventsDefeat() {
        let custom = catalog(with: ["psycho-squad": { DeathWardTestCard(data: $0) }])
        var game = Fixtures.game(catalog: custom)
        let unit = game.place("psycho-squad", for: 0, catalog: custom)
        game.defeat(0, uid: unit)
        XCTAssertNotNil(game.unit(0, unit))
        game.defeat(0, uid: unit)
        XCTAssertNil(game.unit(0, unit))
    }

    func testChooseModeKeepsTheBestEvaluatedBranch() {
        let custom = catalog(with: ["rockn-rockerboy": { ModeTestCard(data: $0) }])
        var game = Fixtures.game(catalog: custom)
        game.playProgram(0, Fixtures.id("rockn-rockerboy", in: custom), bottomAfter: false)
        XCTAssertEqual(game.players[0].hand.count, 2)
    }

    func testVanillaCardsReportTheirMissingText() {
        let status = CoverageReport.status(of: Fixtures.id("delamain-rideshare-ai"), in: Fixtures.catalog)
        guard case .missing(let lines) = status else { return XCTFail("Delamain devrait être à coder") }
        XCTAssertEqual(lines, ["{Play} Draw 2."])
    }
}
