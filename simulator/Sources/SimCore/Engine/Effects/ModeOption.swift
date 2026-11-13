public struct ModeOption: Sendable {
    public static let drawOne = 5.0

    public let name: String
    public let value: Double

    public init(name: String, value: Double) {
        self.name = name
        self.value = value
    }

    static func best(_ options: [ModeOption]) -> Int? {
        var best: Int?
        for index in options.indices where best.map({ options[index].value > options[$0].value }) ?? true {
            best = index
        }
        return best
    }
}
