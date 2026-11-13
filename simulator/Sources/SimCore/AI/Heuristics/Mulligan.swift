extension Game {
    func openingHandScore(_ p: Int, _ ids: [Int]) -> Double {
        let hand = ids.map { stats($0) }.filter { $0.kind != .legend }
        let cheapPlays = hand.filter { $0.costValue <= 3 }.count
        let units = hand.filter { $0.kind == .unit && $0.costValue <= 4 }.count
        let gears = hand.filter { $0.kind == .gear && $0.costValue <= 2 }.count
        let sellables = hand.filter { $0.isSellable }.count
        let heavy = hand.filter { $0.costValue >= 6 }.count
        var score = Double(min(cheapPlays, 4)) * 3
        score += Double(min(units, 2)) * 4
        score += units > 0 && gears > 0 ? 3 : 0
        score += Double(min(sellables, 3)) * 2
        score -= Double(max(heavy - 1, 0)) * 4
        score -= sellables < 2 ? 5 : 0
        return score
    }

    mutating func shouldMulligan(_ p: Int) -> Bool {
        let handSize = players[p].hand.count
        let pool = players[p].hand + players[p].deck
        guard pool.count > handSize else { return false }
        let current = openingHandScore(p, players[p].hand)
        let samples = 40
        var scores: [Double] = []
        for _ in 0..<samples {
            var shuffled = pool
            shuffled.shuffle(using: &rng)
            scores.append(openingHandScore(p, Array(shuffled.prefix(handSize))))
        }
        let mean = scores.reduce(0, +) / Double(samples)
        let variance = scores.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(samples)
        return current < mean - 0.5 * variance.squareRoot()
    }
}
