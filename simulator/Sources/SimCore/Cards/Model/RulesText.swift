import Foundation

public enum RulesTextLine: Sendable, Equatable {
    case flavor
    case reminder
    case keyword(Keyword)
    case effect(String)
}

public enum RulesText {
    static let keywordMarkers: [(marker: String, keyword: Keyword)] = [
        ("{Blocker}", .blocker),
        ("{Adrenaline}", .adrenaline),
        ("{Go Solo}", .goSolo),
    ]

    static let staticSentences: [(sentence: String, keyword: Keyword)] = [
        ("This Unit can't attack.", .cannotAttack),
        ("This Unit can only attack rival Units.", .cannotStealGigs),
        ("This Unit can attack rival Units the turn it's played.", .attacksUnitsWhenPlayed),
    ]

    public static func lines(_ text: String) -> [RulesTextLine] {
        text.split(separator: "\n").compactMap { classify(String($0)) }
    }

    public static func keywords(_ text: String) -> Keyword {
        lines(text).reduce(into: Keyword()) { result, line in
            if case .keyword(let keyword) = line { result.formUnion(keyword) }
        }
    }

    public static func effectLines(_ text: String) -> [String] {
        lines(text).compactMap { line in
            if case .effect(let content) = line { return content }
            return nil
        }
    }

    public static func isFlavorOnly(_ text: String) -> Bool {
        lines(text).allSatisfy { $0 == .flavor || $0 == .reminder }
    }

    static func classify(_ rawLine: String) -> RulesTextLine? {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        if line.isEmpty { return nil }
        if isFlavor(line) { return .flavor }
        if isReminder(line) { return .reminder }
        if let keyword = keywordLine(line) { return .keyword(keyword) }
        if let keyword = staticSentence(line) { return .keyword(keyword) }
        return .effect(line)
    }

    static func isFlavor(_ line: String) -> Bool {
        if line.hasPrefix("[Flavor") || line.hasPrefix("[Flavour") { return true }
        let quotes: [Character] = ["\"", "“", "”"]
        guard let first = line.first, let last = line.last else { return false }
        return quotes.contains(first) && quotes.contains(last)
    }

    static func isReminder(_ line: String) -> Bool {
        line.hasPrefix("(") && line.hasSuffix(")")
    }

    static func keywordLine(_ line: String) -> Keyword? {
        for entry in keywordMarkers where line.hasPrefix(entry.marker) {
            let rest = String(line.dropFirst(entry.marker.count)).trimmingCharacters(in: .whitespaces)
            if rest.isEmpty || isReminder(rest) { return entry.keyword }
        }
        return nil
    }

    static func staticSentence(_ line: String) -> Keyword? {
        let core = withoutTrailingReminder(line)
        return staticSentences.first { $0.sentence == core }?.keyword
    }

    static func withoutTrailingReminder(_ line: String) -> String {
        guard line.hasSuffix(")"), let open = line.lastIndex(of: "(") else { return line }
        return String(line[..<open]).trimmingCharacters(in: .whitespaces)
    }
}
