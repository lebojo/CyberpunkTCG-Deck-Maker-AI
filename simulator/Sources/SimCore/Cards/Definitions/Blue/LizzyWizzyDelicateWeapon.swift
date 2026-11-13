struct LizzyWizzyDelicateWeapon: GameCard {
    let data: CardData
    let listens: EventMask = .played
    var hints: AIHints { .with { $0.threatBonus = 3 } }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .played = event, context.isAboutItself else { return }
        playFreeProgram(&context)
    }

    private func playFreeProgram(_ context: inout EffectContext) {
        var best: (fromHand: Bool, index: Int, value: Double)?
        for (index, id) in context.hand().enumerated() where isCheapProgram(id, context) {
            if let value = context.playValue(id), value > (best?.value ?? 0) { best = (true, index, value) }
        }
        for (index, id) in context.trash().enumerated() where isCheapProgram(id, context) {
            if let value = context.playValue(id, from: .trash), value > (best?.value ?? 0) { best = (false, index, value) }
        }
        guard let choice = best else { return }
        let id: Int
        if choice.fromHand {
            id = context.hand()[choice.index]
            context.takeFromHand(id)
        } else {
            guard let fromTrash = context.takeFromTrash(at: choice.index) else { return }
            id = fromTrash
        }
        context.playProgram(id, bottomAfter: true)
    }

    private func isCheapProgram(_ id: Int, _ reading: some GameReading) -> Bool {
        reading.stats(id).kind == .program && reading.stats(id).costValue <= 3
    }

    func playValue(in query: EffectQuery) -> Double? {
        let hasTarget = query.hand().contains { isCheapProgram($0, query) } || query.trash().contains { isCheapProgram($0, query) }
        return standardPlayValue(in: query).map { $0 + (hasTarget ? 6 : 0) }
    }

    func keepValue(in query: EffectQuery) -> Double {
        standardKeepValue(in: query) + 4
    }
}
