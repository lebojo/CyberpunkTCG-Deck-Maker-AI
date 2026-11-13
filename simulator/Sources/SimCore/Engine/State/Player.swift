struct Gig: Sendable {
    let sides: Int
    var value: Int

    var isMin: Bool { value == 1 }
    var isMax: Bool { value == sides }
}

struct FieldUnit: Sendable {
    let uid: Int
    let cardId: Int
    let isLegend: Bool
    var spent = false
    var lagging = true
    var gears: [Int] = []
    var bonusPower = 0
    var fightBonus = 0
    var cannotAttackBefore = 0
    var defeatAtEnd = false
    var stoleThisTurn = false
    var readiedByWin = false
}

struct LegendSlot: Sendable {
    let cardId: Int
    var faceUp = false
    var spent = false
    var gears: [Int] = []
}

struct TurnFlags: Sendable {
    var sold = false
    var called = false
    var programsPlayed = 0
    var jackieUsed = false
    var yorinobuUsed = false
    var programDiscount = 0
    var safetyOverrides = 0
    var cyberwareDiscountUsed = false
    var altTrashUsed = false
}

struct Player: Sendable {
    var deck: [Int]
    var hand: [Int] = []
    var eddiesReady = 0
    var eddiesSpent = 0
    var trash: [Int] = []
    var legends: [LegendSlot]
    var field: [FieldUnit] = []
    var gigs: [Gig] = []
    var fixer: [Int] = [4, 6, 8, 10, 12, 20]
    var flags = TurnFlags()
    var mulliganed = false
    var wantsMinGigs = false
    var revealed: [Int] = []
}

enum WinReason: Sendable {
    case gigsAtStart
    case gigsInOvertime
    case deckOut
    case turnLimit
}

enum Outcome: Sendable {
    case ongoing
    case win(player: Int, reason: WinReason)
    case draw
}

enum AttackTarget: Sendable, Hashable {
    case gigs
    case unit(Int)
}

enum EquipTarget: Sendable, Hashable {
    case unit(Int)
    case legend(Int)
}
