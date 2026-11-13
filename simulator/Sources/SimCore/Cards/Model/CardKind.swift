public enum CardKind: String, Sendable, Codable, CaseIterable {
    case legend = "Legend"
    case unit = "Unit"
    case gear = "Gear"
    case program = "Program"

    public var frenchName: String {
        switch self {
        case .legend: return "Légendes"
        case .unit: return "Units"
        case .gear: return "Gears"
        case .program: return "Programs"
        }
    }
}

public enum CardColor: String, Sendable, Codable, CaseIterable {
    case blue = "Blue"
    case green = "Green"
    case yellow = "Yellow"
    case red = "Red"

    public var frenchName: String {
        switch self {
        case .blue: return "Bleu"
        case .green: return "Vert"
        case .yellow: return "Jaune"
        case .red: return "Rouge"
        }
    }
}
