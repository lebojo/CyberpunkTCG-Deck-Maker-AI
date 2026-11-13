struct DeadmanTransmitter: GameCard {
    let data: CardData
    let listens: EventMask = .wouldBeDefeated
    var hints: AIHints { .with { $0.gearRemovalPriority = 4 } }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .wouldBeDefeated(let uid, _) = event, context.isAboutHost,
              case .unit(let hostUid)? = context.host, hostUid == uid else { return }
        context.prevent()
        context.defeatGear(GearTarget(owner: context.owner, host: .unit(uid), gear: context.cardId))
        context.note("P\(context.owner) defeats Deadman Transmitter instead")
    }

    func playValue(in query: EffectQuery) -> Double? {
        standardPlayValue(in: query).map { $0 + 5 }
    }

    func keepValue(in query: EffectQuery) -> Double {
        standardKeepValue(in: query) + 2
    }
}
