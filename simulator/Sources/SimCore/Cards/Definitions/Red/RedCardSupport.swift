extension GameReading {
    var friendlyGigsWith8PlusValue: Int { gigs().filter { $0.value >= 8 }.count }
}
