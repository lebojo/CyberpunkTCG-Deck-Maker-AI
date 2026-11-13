public enum CardLocation: Sendable, Hashable {
    case hand
    case field(uid: Int)
    case legend(slot: Int)
    case gear(host: EquipTarget)
    case trash
    case resolving
    case removed
    case delayed(id: Int)
}

public enum EventRelation: Sendable, Hashable {
    case itself
    case attachedTo
    case ally
    case rival
    case delayed
}

public enum DefeatCause: Sendable, Hashable {
    case fight(opponentUid: Int)
    case effect
}

public struct DefeatedUnit: Sendable, Hashable {
    public let uid: Int
    public let cardId: Int
    public let gears: [Int]
    public let wasLegend: Bool

    public var wasEquipped: Bool { !gears.isEmpty }
}

public struct FightReport: Sendable, Hashable {
    public let unitUid: Int
    public let opponentUid: Int
    public let power: Int
    public let opponentPower: Int
}

public enum GameEvent: Sendable {
    case played(cardId: Int, location: CardLocation)
    case programResolves
    case calledAsLegend(slot: Int)
    case attackDeclared(attackerUid: Int, target: AttackTarget)
    case blocked(blockerUid: Int, attackerUid: Int)
    case becameSpent(CardLocation, isEquipped: Bool)
    case wouldBeDefeated(uid: Int, cause: DefeatCause)
    case defeated(DefeatedUnit)
    case gigWouldBeStolen(Gig, attackerUid: Int)
    case stoleGigs(attackerUid: Int, gigs: [Gig])
    case gigStolen(Gig, attackerUid: Int)
    case gigsAlteredByRival
    case wonFight(FightReport)
    case lostFight(FightReport)
    case turnStarted
    case endOfTurn
    case gigRolled(index: Int)
    case quickActivated(cardId: Int)

    public var mask: EventMask {
        switch self {
        case .played: return .played
        case .programResolves: return .programResolves
        case .calledAsLegend: return .calledAsLegend
        case .attackDeclared: return .attackDeclared
        case .blocked: return .blocked
        case .becameSpent: return .becameSpent
        case .wouldBeDefeated: return .wouldBeDefeated
        case .defeated: return .defeated
        case .gigWouldBeStolen: return .gigWouldBeStolen
        case .stoleGigs: return .stoleGigs
        case .gigStolen: return .gigStolen
        case .gigsAlteredByRival: return .gigsAlteredByRival
        case .wonFight: return .wonFight
        case .lostFight: return .lostFight
        case .turnStarted: return .turnStarted
        case .endOfTurn: return .endOfTurn
        case .gigRolled: return .gigRolled
        case .quickActivated: return .quickActivated
        }
    }
}

public struct EventMask: OptionSet, Sendable, Hashable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let played = EventMask(rawValue: 1 << 0)
    public static let programResolves = EventMask(rawValue: 1 << 1)
    public static let calledAsLegend = EventMask(rawValue: 1 << 2)
    public static let attackDeclared = EventMask(rawValue: 1 << 3)
    public static let blocked = EventMask(rawValue: 1 << 4)
    public static let becameSpent = EventMask(rawValue: 1 << 5)
    public static let wouldBeDefeated = EventMask(rawValue: 1 << 6)
    public static let defeated = EventMask(rawValue: 1 << 7)
    public static let gigWouldBeStolen = EventMask(rawValue: 1 << 8)
    public static let stoleGigs = EventMask(rawValue: 1 << 9)
    public static let gigStolen = EventMask(rawValue: 1 << 10)
    public static let gigsAlteredByRival = EventMask(rawValue: 1 << 11)
    public static let wonFight = EventMask(rawValue: 1 << 12)
    public static let lostFight = EventMask(rawValue: 1 << 13)
    public static let turnStarted = EventMask(rawValue: 1 << 14)
    public static let endOfTurn = EventMask(rawValue: 1 << 15)
    public static let gigRolled = EventMask(rawValue: 1 << 16)
    public static let quickActivated = EventMask(rawValue: 1 << 17)
}
