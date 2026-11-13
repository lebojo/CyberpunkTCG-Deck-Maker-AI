public enum AbilityTiming: Int, Sendable, Hashable, CaseIterable {
    case mainAction
    case beforeAttacks
    case endOfMainPhase
    case beforePlayingCard
    case beforeAttack
    case fight
    case rivalAttacksGigs
}

public struct AbilityTimings: OptionSet, Sendable, Hashable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public init(_ timings: [AbilityTiming]) {
        self.init(rawValue: timings.reduce(0) { $0 | (1 << UInt8($1.rawValue)) })
    }

    public func contains(_ timing: AbilityTiming) -> Bool {
        rawValue & (1 << UInt8(timing.rawValue)) != 0
    }
}

public struct ActivatedAbility: Sendable, Hashable {
    public let index: Int
    public let name: String
    public let timing: AbilityTiming
    public let eddieCost: Int
    public let spendsSource: Bool

    public init(index: Int, name: String, timing: AbilityTiming, eddieCost: Int = 0, spendsSource: Bool = true) {
        self.index = index
        self.name = name
        self.timing = timing
        self.eddieCost = eddieCost
        self.spendsSource = spendsSource
    }
}

public enum AbilityTarget: Sendable, Hashable {
    case none
    case card(Int)
    case unit(owner: Int, uid: Int)
    case gig(owner: Int, index: Int)
    case mode(Int)
}

public enum FightPreview: Sendable, Hashable {
    case power(own: Int, other: Int)
    case retaliation
}

public struct AbilityOption: Sendable, Hashable {
    public var ability: Int
    public var target: AbilityTarget
    public var value: Double
    public var eddieCost: Int
    public var fight: FightPreview?
    public var stealReduction: Int

    public init(ability: Int, target: AbilityTarget = .none, value: Double = 0, eddieCost: Int = 0, fight: FightPreview? = nil, stealReduction: Int = 0) {
        self.ability = ability
        self.target = target
        self.value = value
        self.eddieCost = eddieCost
        self.fight = fight
        self.stealReduction = stealReduction
    }
}
