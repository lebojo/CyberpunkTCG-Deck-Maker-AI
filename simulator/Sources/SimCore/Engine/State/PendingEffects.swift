public enum EffectExpiry: Sendable, Hashable {
    case endOfTurn
    case untilYourNextTurn
}

struct PendingDiscount: Sendable {
    let sourceCardId: Int
    let kind: CardKind?
    let amount: Int
    let minimum: Int
}

struct DelayedTrigger: Sendable {
    let id: Int
    let sourceCardId: Int
    let listens: EventMask
    let expiry: EffectExpiry
    var charges: Int
    let payload: Int
}
