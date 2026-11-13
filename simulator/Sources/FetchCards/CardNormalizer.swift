enum CardNormalizer {
    static let fields: [(output: String, input: String)] = [
        ("name", "name"),
        ("subname", "subname"),
        ("canonicalName", "canonical_name"),
        ("kind", "card_type"),
        ("color", "color"),
        ("cost", "cost"),
        ("power", "power"),
        ("ram", "ram"),
        ("sellable", "is_eddiable"),
        ("classifications", "classifications"),
        ("rulesText", "rules_text"),
        ("printNumber", "print_number"),
        ("legality", "legality"),
    ]

    static func normalize(_ raw: [String: Any]) -> JSONValue {
        var pairs: [(String, JSONValue)] = []
        let canonical = (raw["canonical_name"] as? String) ?? (raw["name"] as? String) ?? ""
        pairs.append(("key", .string(slug(canonical))))
        for field in fields {
            var value = JSONValue(any: raw[field.input])
            if field.output == "rulesText", value == .null { value = .string("") }
            if field.output == "classifications", value == .null { value = .array([]) }
            pairs.append((field.output, value))
        }
        return .object(pairs)
    }

    static func slug(_ name: String) -> String {
        var result = ""
        var pendingDash = false
        for scalar in name.lowercased().unicodeScalars {
            let isAlphanumeric = ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar)
            if isAlphanumeric {
                if pendingDash && !result.isEmpty { result += "-" }
                pendingDash = false
                result.unicodeScalars.append(scalar)
            } else {
                pendingDash = true
            }
        }
        return result
    }

    static func sortKey(_ card: JSONValue) -> [UInt32] {
        (card["canonicalName"]?.stringValue ?? "").unicodeScalars.map(\.value)
    }

    static func sorted(_ cards: [JSONValue]) -> [JSONValue] {
        cards.sorted { sortKey($0).lexicographicallyPrecedes(sortKey($1)) }
    }
}
