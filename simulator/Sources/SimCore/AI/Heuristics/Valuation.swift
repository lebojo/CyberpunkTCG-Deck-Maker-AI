public extension GameCard {
    func standardPlayValue(in query: EffectQuery) -> Double? {
        let game = query.game
        switch data.kind {
        case .unit:
            var value = 20 + Double(data.power) * 1.2 + Double(data.costValue) * 1.5
            if game.turn <= 8 && data.costValue <= 3 { value += 4 }
            return value
        case .gear:
            guard game.equipTarget(query.owner, gear: query.cardId) != nil else { return nil }
            return 24 + Double(data.power) * 2
        case .program:
            return 8
        case .legend:
            return nil
        }
    }

    func standardKeepValue(in query: EffectQuery) -> Double {
        switch data.kind {
        case .unit:
            return 14 + Double(data.costValue) * 0.8
        case .gear:
            var value = 8 + Double(data.power)
            if query.game.players[query.owner].field.isEmpty { value -= 2 }
            return value
        case .program:
            if let value = playValue(in: query) { return min(value * 0.5, 14) }
            return 4
        case .legend:
            return 0
        }
    }
}

extension Game {
    func keepValue(_ p: Int, _ id: Int) -> Double {
        implementation(id).keepValue(in: query(id, owner: p, at: .hand))
    }

    func playValue(_ p: Int, _ id: Int, from location: CardLocation = .hand) -> Double? {
        implementation(id).playValue(in: query(id, owner: p, at: location))
    }
}
