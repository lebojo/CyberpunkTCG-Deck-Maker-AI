extension Game {
    func streetCred(_ p: Int) -> Int? {
        players[p].gigs.isEmpty ? nil : players[p].gigs.reduce(0) { $0 + $1.value }
    }

    func hasMoreStreetCred(_ p: Int) -> Bool {
        guard let mine = streetCred(p) else { return false }
        guard let theirs = streetCred(1 - p) else { return true }
        return mine > theirs
    }

    func hasLessStreetCred(_ p: Int) -> Bool {
        guard let theirs = streetCred(1 - p) else { return false }
        guard let mine = streetCred(p) else { return true }
        return mine < theirs
    }

    func valuePairs(_ p: Int) -> Int {
        Dictionary(grouping: players[p].gigs, by: { $0.value }).values.reduce(0) { $0 + $1.count / 2 }
    }

    func minGigCount(_ p: Int) -> Int {
        players[p].gigs.filter { $0.isMin }.count
    }

    func maxGigCount(_ p: Int) -> Int {
        players[p].gigs.filter { $0.isMax }.count
    }

    func distinctGigValues(_ p: Int) -> Int {
        Set(players[p].gigs.map { $0.value }).count
    }

    func hasGigAtLeast(_ p: Int, _ value: Int) -> Bool {
        players[p].gigs.contains { $0.value >= value }
    }

    func hasEvenAndOddGig(_ p: Int) -> Bool {
        let gigs = players[p].gigs
        return gigs.contains { $0.isEven } && gigs.contains { !$0.isEven }
    }

    mutating func adjustGig(_ p: Int, index: Int, to value: Int) {
        guard players[p].gigs.indices.contains(index) else { return }
        let gig = players[p].gigs[index]
        guard value >= 1, value <= gig.sides, value != gig.value else { return }
        players[p].gigs[index].value = value
    }

    mutating func swapGigs(_ p: Int, mine: Int, theirs: Int) {
        guard players[p].gigs.indices.contains(mine), players[1 - p].gigs.indices.contains(theirs) else { return }
        let given = players[p].gigs[mine]
        players[p].gigs[mine] = players[1 - p].gigs[theirs]
        players[1 - p].gigs[theirs] = given
    }
}
