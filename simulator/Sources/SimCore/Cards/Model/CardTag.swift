public struct CardTag: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue.lowercased()
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public static let ai: CardTag = "ai"
    public static let arasaka: CardTag = "arasaka"
    public static let braindance: CardTag = "braindance"
    public static let corpo: CardTag = "corpo"
    public static let cyberware: CardTag = "cyberware"
    public static let drone: CardTag = "drone"
    public static let ganger: CardTag = "ganger"
    public static let merc: CardTag = "merc"
    public static let netrunner: CardTag = "netrunner"
    public static let quickhack: CardTag = "quickhack"
    public static let rocker: CardTag = "rocker"
    public static let vehicle: CardTag = "vehicle"
}
