struct PadreManOfTheCross: GameCard {
    let data: CardData
    let listens: EventMask = .calledAsLegend
    var hints: AIHints { .with { $0.manaReluctance = 5 } }

    var abilities: [ActivatedAbility] {
        [ActivatedAbility(index: 0, name: "Padre : match a Gig", timing: .beforeAttacks)]
    }

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .calledAsLegend = event, context.isAboutItself else { return }
        let options = [ModeOption(name: "spend a rival Unit", value: spendValue(context)), ModeOption(name: "draw 1", value: ModeOption.drawOne)]
        _ = context.chooseMode(options) { mode, branch in
            if mode == 0 {
                if let target = branch.bestRivalUnit(where: { !$0.spent }) { branch.spendUnit(branch.rival, uid: target.uid) }
            } else {
                branch.draw(1)
            }
        }
    }

    private func spendValue(_ reading: some GameReading) -> Double {
        guard let target = reading.bestRivalUnit(where: { !$0.spent }) else { return 0 }
        let threat = reading.unitThreat(target, owner: reading.rival)
        return reading.isBlocker(target, owner: reading.rival) ? threat : threat / 2
    }

    func abilityOptions(_ ability: ActivatedAbility, in query: EffectQuery) -> [AbilityOption] {
        guard let match = bestMatch(in: query) else { return [] }
        return [AbilityOption(ability: 0, target: .gig(owner: match.owner, index: match.index))]
    }

    func activate(_ option: AbilityOption, in context: inout EffectContext) -> Bool {
        guard let slot = context.selfLegendSlot, !context.legends()[slot].spent, let match = bestMatch(in: context) else { return false }
        context.spendLegend(slot: slot)
        context.note("P\(context.owner) sets a Gig of P\(match.owner) to \(match.value)")
        context.setGig(match.owner, index: match.index, to: match.value)
        return true
    }

    private struct Match {
        let owner: Int
        let index: Int
        let value: Int
        let gain: Double
    }

    private static let minimumRivalDamage = 2.0

    private func bestMatch(in reading: some GameReading) -> Match? {
        let candidates = ownMatches(in: reading) + rivalMatches(in: reading)
        return candidates.max { $0.gain < $1.gain }
    }

    private func ownMatches(in reading: some GameReading) -> [Match] {
        let owner = reading.owner
        let mine = reading.gigs()
        let values = Set(reading.gigs(of: reading.rival).map(\.value)).sorted()
        let baseline = reading.gigScore(mine)
        return mine.indices.flatMap { index in
            values.compactMap { value -> Match? in
                guard value != mine[index].value, value <= mine[index].sides else { return nil }
                var trial = mine
                trial[index].value = value
                let gain = reading.gigScore(trial) - baseline
                return gain > 0 ? Match(owner: owner, index: index, value: value, gain: gain) : nil
            }
        }
    }

    private func rivalMatches(in reading: some GameReading) -> [Match] {
        let rival = reading.rival
        let theirs = reading.gigs(of: rival)
        let values = Set(reading.gigs().map(\.value)).sorted()
        let baseline = reading.gigScore(theirs, for: rival)
        return theirs.indices.flatMap { index in
            values.compactMap { value -> Match? in
                guard value != theirs[index].value, value <= theirs[index].sides else { return nil }
                var trial = theirs
                trial[index].value = value
                let damage = baseline - reading.gigScore(trial, for: rival)
                return damage >= Self.minimumRivalDamage ? Match(owner: rival, index: index, value: value, gain: damage) : nil
            }
        }
    }
}
