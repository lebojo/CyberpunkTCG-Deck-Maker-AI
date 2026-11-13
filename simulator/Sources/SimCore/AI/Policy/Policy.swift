public struct SearchConfig: Sendable, Hashable {
    public var samples: Int
    public var depth: Int
    public var shortlist: Int
    public var opponentBudget: Int
    public var maxSteps: Int
    public var bluff: Bool
    public var legacy: Bool
    public var isSimulatedOpponent: Bool

    public init(samples: Int = 3, depth: Int = 3, shortlist: Int = 4, opponentBudget: Int = 1, maxSteps: Int = 18, bluff: Bool = SearchConfig.defaultBluff, legacy: Bool = false, isSimulatedOpponent: Bool = false) {
        self.samples = samples
        self.depth = depth
        self.shortlist = shortlist
        self.opponentBudget = opponentBudget
        self.maxSteps = maxSteps
        self.bluff = bluff
        self.legacy = legacy
        self.isSimulatedOpponent = isSimulatedOpponent
    }

    public static let defaultBluff = false

    public static let legacyBaseline = SearchConfig(opponentBudget: 0, bluff: false, legacy: true)

    func simulatedOpponent(playing rival: SearchConfig) -> SearchConfig {
        SearchConfig(samples: 1, depth: 0, shortlist: 0, opponentBudget: 0, maxSteps: opponentBudget, bluff: rival.bluff, legacy: rival.legacy, isSimulatedOpponent: true)
    }

    var modelsOpponent: Bool { !legacy && opponentBudget > 0 }
}

public struct Policy: Sendable, Hashable {
    public var search: Bool
    public var config: SearchConfig

    public init(search: Bool, config: SearchConfig = SearchConfig()) {
        self.search = search
        self.config = config
    }

    public static let greedy = Policy(search: false)

    public var legacy: Policy {
        var copy = self
        copy.config.opponentBudget = 0
        copy.config.bluff = false
        copy.config.legacy = true
        return copy
    }
}
