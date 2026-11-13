public struct ModifierScopes: OptionSet, Sendable, Hashable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public static let itself = ModifierScopes(rawValue: 1 << 0)
    public static let equippedUnit = ModifierScopes(rawValue: 1 << 1)
    public static let alliedUnits = ModifierScopes(rawValue: 1 << 2)
    public static let rivalUnits = ModifierScopes(rawValue: 1 << 3)
    public static let ownPlayCost = ModifierScopes(rawValue: 1 << 4)
    public static let alliedPlayCost = ModifierScopes(rawValue: 1 << 5)
    public static let fight = ModifierScopes(rawValue: 1 << 6)
    public static let goSoloCost = ModifierScopes(rawValue: 1 << 7)
    public static let alliedAttackers = ModifierScopes(rawValue: 1 << 8)

    public static let unitScopes: ModifierScopes = [.itself, .equippedUnit, .alliedUnits, .rivalUnits, .alliedAttackers]
    public static let staticUnitScopes: ModifierScopes = [.itself, .equippedUnit, .alliedUnits, .rivalUnits]
}

public struct CardModifiers: Sendable {
    public var power = 0
    public var keywords: Keyword = []
    public var fightPower = 0
    public var winsFight = false
    public var costOverride: Int?
    public var costReduction = 0
    public var costMinimum = 1
    public var costOncePerTurnKey: Int?
    public var goSoloCostChange = 0

    public init() {}

    public static let none = CardModifiers()

    public static func with(_ configure: (inout CardModifiers) -> Void) -> CardModifiers {
        var modifiers = CardModifiers()
        configure(&modifiers)
        return modifiers
    }
}
