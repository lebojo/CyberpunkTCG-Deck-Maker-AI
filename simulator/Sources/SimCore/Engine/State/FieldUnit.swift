public struct FieldUnit: Sendable {
    public let uid: Int
    public let cardId: Int
    public let isLegend: Bool
    public internal(set) var spent = false
    public internal(set) var lagging = true
    public internal(set) var gears: [Int] = []
    var bonusPower = 0
    var fightBonus = 0
    var lingeringPower = 0
    var lingeringPowerUntil = 0
    var cannotAttackBefore = 0
    var cannotReadyBefore = 0
    var mustAttackOnTurn = 0
    var defeatAtEnd = false
    var grantedKeywords: Keyword = []
    var turnMarks: [Int] = []

    init(uid: Int, cardId: Int, isLegend: Bool) {
        self.uid = uid
        self.cardId = cardId
        self.isLegend = isLegend
    }

    public var isEquipped: Bool { !gears.isEmpty }

    mutating func clearTurnState() {
        bonusPower = 0
        fightBonus = 0
        lagging = false
        defeatAtEnd = false
        grantedKeywords = []
        if !turnMarks.isEmpty { turnMarks = [] }
    }
}

public struct LegendSlot: Sendable {
    public let cardId: Int
    public internal(set) var faceUp = false
    public internal(set) var spent = false
    public internal(set) var gears: [Int] = []

    init(cardId: Int, faceUp: Bool = false, spent: Bool = false, gears: [Int] = []) {
        self.cardId = cardId
        self.faceUp = faceUp
        self.spent = spent
        self.gears = gears
    }
}
