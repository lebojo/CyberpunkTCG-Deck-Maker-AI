public enum QuerySubject: Sendable, Hashable {
    case none
    case unit(owner: Int, uid: Int)
    case legend(owner: Int, slot: Int)
    case card(Int)
    case fight(ownUid: Int, otherUid: Int)
    case attack(owner: Int, uid: Int)
}

public struct EffectQuery: GameReading {
    public let game: Game
    public let owner: Int
    public let cardId: Int
    public let location: CardLocation
    public let subject: QuerySubject
    public let attacking: Bool

    init(game: Game, owner: Int, cardId: Int, location: CardLocation, subject: QuerySubject = .none, attacking: Bool = false) {
        self.game = game
        self.owner = owner
        self.cardId = cardId
        self.location = location
        self.subject = subject
        self.attacking = attacking
    }
}

public struct EffectContext: GameReading {
    public internal(set) var game: Game
    public let owner: Int
    public let cardId: Int
    public let location: CardLocation
    public let relation: EventRelation
    public let subject: QuerySubject
    public let delayedPayload: Int
    var outcome = EventOutcome()

    init(game: Game, owner: Int, cardId: Int, location: CardLocation, relation: EventRelation, subject: QuerySubject = .none, delayedPayload: Int = 0) {
        self.game = game
        self.owner = owner
        self.cardId = cardId
        self.location = location
        self.relation = relation
        self.subject = subject
        self.delayedPayload = delayedPayload
    }

    public var isAboutItself: Bool { relation == .itself }
    public var isAboutHost: Bool { relation == .attachedTo }
    public var isAboutAlly: Bool { relation == .ally }
    public var isDelayedTrigger: Bool { relation == .delayed }
}

extension Game {
    func query(_ cardId: Int, owner: Int, at location: CardLocation, subject: QuerySubject = .none, attacking: Bool = false) -> EffectQuery {
        EffectQuery(game: self, owner: owner, cardId: cardId, location: location, subject: subject, attacking: attacking)
    }

    mutating func withContext<Result>(_ cardId: Int, owner: Int, at location: CardLocation, subject: QuerySubject = .none, _ body: (inout EffectContext) -> Result) -> Result {
        var context = EffectContext(game: Game(placeholderFor: catalog), owner: owner, cardId: cardId, location: location, relation: .itself, subject: subject)
        swap(&self, &context.game)
        let result = body(&context)
        swap(&self, &context.game)
        return result
    }
}
