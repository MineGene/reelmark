import Foundation

/// The text typed in the window's search field, matched the way Finder and
/// Activity Monitor match theirs: ignoring case and accents, and every word
/// must appear somewhere, in any order ("dune 2024" finds "Dune (2024)").
public struct ListSearch: Sendable, Equatable {
    public let words: [String]

    public init(_ text: String) {
        words = text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// True when nothing is typed, so everything is shown.
    public var isEmpty: Bool { words.isEmpty }

    /// Whether every word appears in at least one of `fields`.
    public func matches(_ fields: [String]) -> Bool {
        words.allSatisfy { word in fields.contains { $0.localizedStandardContains(word) } }
    }
}
