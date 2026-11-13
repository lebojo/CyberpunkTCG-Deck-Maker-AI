struct SidePair<Value: Sendable>: Sendable {
    var first: Value
    var second: Value

    init(_ first: Value, _ second: Value) {
        self.first = first
        self.second = second
    }

    init(_ values: [Value]) {
        self.init(values[0], values[1])
    }

    subscript(side: Int) -> Value {
        get { side == 0 ? first : second }
        set { if side == 0 { first = newValue } else { second = newValue } }
    }
}
