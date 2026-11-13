public struct AIHints: Sendable {
    public var threatBonus: Double = 0
    public var gearRemovalPriority = 2
    public var prefersNoGears = false
    public var extraPowerPerGear = 0
    public var carriesGearsAsLegend = false
    public var suitsFaceUpLegend = false
    public var manaReluctance = 1
    public var rewardsBeingSpent = false
    public var goSoloBonus: Double = 0
    public var ignoresExposure = false
    public var attackWithoutStealValue: Double = -10

    public init() {}

    public static func with(_ configure: (inout AIHints) -> Void) -> AIHints {
        var hints = AIHints()
        configure(&hints)
        return hints
    }
}
