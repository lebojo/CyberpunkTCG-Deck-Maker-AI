struct TheRelicExperimentalBiochip: GameCard {
    let data: CardData
    let listens: EventMask = .defeated

    func action(_ event: GameEvent, in context: inout EffectContext) {
        guard case .defeated(let report) = event, context.isAboutHost else { return }
        let trash = context.trash()
        let defeatedPosition = trash.lastIndex(of: report.cardId)
        let candidates = trash.indices.filter { index in
            context.stats(trash[index]).kind == .unit && context.stats(trash[index]).costValue <= 9 && (report.wasLegend || index != defeatedPosition)
        }
        guard let best = candidates.max(by: { revivalValue(trash[$0], context) < revivalValue(trash[$1], context) }),
              let revived = context.takeFromTrash(at: best) else { return }
        if !report.wasLegend, context.takeLastFromTrash(report.cardId) {
            context.bottomDeck([report.cardId])
        }
        context.note("P\(context.owner) revives \(context.data(revived).canonicalName) with The Relic")
        context.putUnitIntoPlay(revived)
    }

    private func revivalValue(_ id: Int, _ context: EffectContext) -> Double {
        context.playValue(id, from: .trash) ?? 0
    }

    func playValue(in query: EffectQuery) -> Double? {
        let hasUnitInTrash = query.trash().contains { query.stats($0).kind == .unit }
        return standardPlayValue(in: query).map { $0 + (hasUnitInTrash ? 5 : 0) }
    }
}
