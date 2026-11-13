struct PadreManOfTheCross: GameCard {
    let data: CardData
    let listens: EventMask = .calledAsLegend
    var hints: AIHints { .with { $0.manaReluctance = 5 } }

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Padre : match a Gig", timing: .beforeAttacks)]
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .calledAsLegend = event, context.isAboutItself else { return }
        _ = context.chooseMode(2) { mode, branch in
            if mode == 0 {
                if let target = branch.bestRivalUnit(where: { !$0.spent }) { branch.spendUnit(branch.rival, uid: target.uid) }
            } else {
                branch.draw(1)
            }
        }
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        guard let match = bestMatch(in: query) else { return [] }
        return [AbilityOption(ability: 0, target: .gig(owner: query.owner, index: match.index))]
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard let slot = context.selfLegendSlot, !context.legends()[slot].spent, let match = bestMatch(in: context) else { return false }
        context.spendLegend(slot: slot)
        context.note("P\(context.owner) sets a Gig to \(match.value)")
        context.setGig(context.owner, index: match.index, to: match.value)
        return true
    }

    private func bestMatch(in reading: some GameReading) -> (index: Int, value: Int)? {
        let mine = reading.gigs()
        let values = Set(mine.map(\.value) + reading.gigs(of: reading.rival).map(\.value)).sorted()
        let baseline = reading.gigScore(mine)
        var best: (index: Int, value: Int, score: Double)?
        for index in mine.indices {
            for value in values where value != mine[index].value && value <= mine[index].sides {
                var trial = mine
                trial[index].value = value
                let score = reading.gigScore(trial)
                if score > baseline, score > (best?.score ?? -Double.infinity) { best = (index, value, score) }
            }
        }
        return best.map { ($0.index, $0.value) }
    }
}
