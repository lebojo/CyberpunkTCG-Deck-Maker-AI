public struct Keyword: OptionSet, Sendable, Hashable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let blocker = Keyword(rawValue: 1 << 0)
    public static let adrenaline = Keyword(rawValue: 1 << 1)
    public static let goSolo = Keyword(rawValue: 1 << 2)
    public static let cannotAttack = Keyword(rawValue: 1 << 3)
    public static let cannotStealGigs = Keyword(rawValue: 1 << 4)
    public static let unblockable = Keyword(rawValue: 1 << 5)
    public static let canAttackReadyUnits = Keyword(rawValue: 1 << 6)
    public static let canAttackReadyBlockers = Keyword(rawValue: 1 << 7)
    public static let attacksUnitsWhenPlayed = Keyword(rawValue: 1 << 8)
    public static let attacksGigsWhenPlayed = Keyword(rawValue: 1 << 9)

    public static let grantedByGear: Keyword = [.blocker, .adrenaline, .unblockable, .canAttackReadyUnits]
}
