public enum WinReason: Sendable {
    case gigsAtStart
    case gigsInOvertime
    case deckOut
    case turnLimit
    case tieInOvertime
}

public enum Outcome: Sendable {
    case ongoing
    case win(player: Int, reason: WinReason)
    case draw(reason: WinReason)
}

public enum AttackTarget: Sendable, Hashable {
    case gigs
    case unit(Int)
}

public enum EquipTarget: Sendable, Hashable {
    case unit(Int)
    case legend(Int)
}
