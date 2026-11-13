import Foundation

enum JSONValue: Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Int)
    case string(String)
    case array([JSONValue])
    case object([(String, JSONValue)])

    static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
        lhs.serialized(indent: 0) == rhs.serialized(indent: 0)
    }

    init(any value: Any?) {
        switch value {
        case let number as NSNumber:
            self = CFGetTypeID(number) == CFBooleanGetTypeID() ? .bool(number.boolValue) : .number(number.intValue)
        case let text as String: self = .string(text)
        case let list as [Any]: self = .array(list.map { JSONValue(any: $0) })
        default: self = .null
        }
    }

    func serialized(indent level: Int) -> String {
        switch self {
        case .null: return "null"
        case .bool(let flag): return flag ? "true" : "false"
        case .number(let number): return String(number)
        case .string(let text): return JSONValue.quoted(text)
        case .array(let items):
            guard !items.isEmpty else { return "[]" }
            let inner = String(repeating: " ", count: level + 1)
            let body = items.map { inner + $0.serialized(indent: level + 1) }.joined(separator: ",\n")
            return "[\n" + body + "\n" + String(repeating: " ", count: level) + "]"
        case .object(let pairs):
            guard !pairs.isEmpty else { return "{}" }
            let inner = String(repeating: " ", count: level + 1)
            let body = pairs.map { inner + JSONValue.quoted($0.0) + ": " + $0.1.serialized(indent: level + 1) }.joined(separator: ",\n")
            return "{\n" + body + "\n" + String(repeating: " ", count: level) + "}"
        }
    }

    static func quoted(_ text: String) -> String {
        var result = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            case "\u{08}": result += "\\b"
            case "\u{0C}": result += "\\f"
            default:
                if scalar.value < 0x20 {
                    result += "\\u" + hexDigits(scalar.value)
                } else {
                    result.unicodeScalars.append(scalar)
                }
            }
        }
        return result + "\""
    }

    subscript(key: String) -> JSONValue? {
        guard case .object(let pairs) = self else { return nil }
        return pairs.first { $0.0 == key }?.1
    }

    var stringValue: String? {
        if case .string(let text) = self { return text }
        return nil
    }
}

func hexDigits(_ value: UInt32) -> String {
    let hex = String(value, radix: 16)
    return String(repeating: "0", count: max(0, 4 - hex.count)) + hex
}
