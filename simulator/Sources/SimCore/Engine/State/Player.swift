public struct Gig: Sendable, Hashable {
    public let sides: Int
    public var value: Int

    public init(sides: Int, value: Int) {
        self.sides = sides
        self.value = value
    }

    public var isMin: Bool { value == 1 }
    public var isMax: Bool { value == sides }
    public var isEven: Bool { value % 2 == 0 }
}

struct TurnFlags: Sendable {
    var sold = false
    var called = false
    var programsPlayed = 0
    var usedOncePerTurn: [Int] = []
    var pendingDiscounts: [PendingDiscount] = []
    var delayedTriggers: [DelayedTrigger] = []
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
