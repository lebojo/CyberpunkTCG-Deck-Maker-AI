struct VanillaCard: GameCard {
    let data: CardData
    let listens: EventMask = []

    var unimplementedText: [String] { RulesText.effectLines(data.rulesText) }
}
