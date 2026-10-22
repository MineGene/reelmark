import Foundation

/// A movie or show found in The Movie Database (TMDB).
public struct Match: Identifiable, Hashable, Sendable {
    public enum Kind: String, Hashable, Sendable {
        case movie, show
    }

    /// TMDB's id. Jellyfin reads it from the folder name, so the right
    /// entry is used even when titles are ambiguous.
    public let id: Int
    public let kind: Kind
    public let title: String
    public let year: Int?
    public let overview: String

    public init(id: Int, kind: Kind, title: String, year: Int?, overview: String = "") {
        self.id = id
        self.kind = kind
        self.title = title
        self.year = year
        self.overview = overview
    }

    /// "Dune: Part Two (2024)", for showing in lists.
    public var displayName: String {
        year.map { "\(title) (\($0))" } ?? title
    }
}

/// Builds names that Jellyfin recognises without any manual fixing:
///
///     Dune - Part Two (2024) [tmdbid-693134]/Dune - Part Two (2024) [tmdbid-693134].mkv
///     Severance (2022) [tmdbid-95396]/Season 01/Severance S01E02.mkv
///
/// See https://jellyfin.org/docs/general/server/media/movies and
/// https://jellyfin.org/docs/general/server/media/shows
public enum JellyfinNaming {

    /// The path to create inside the Movies or Shows library folder.
    public static func relativePath(for parsed: ParsedName, match: Match, fileExtension: String) -> String {
        let folder = safe("\(match.displayName) [tmdbid-\(match.id)]")
        let ext = fileExtension.isEmpty ? "" : "." + fileExtension.lowercased()

        switch parsed.kind {
        case .movie:
            return "\(folder)/\(folder)\(ext)"
        case .episode(let season, let episodes):
            let seasonNumber = twoDigits(season)
            var code = "S\(seasonNumber)E\(twoDigits(episodes.first ?? 0))"
            if episodes.count > 1, let last = episodes.last {
                code += "-E\(twoDigits(last))"
            }
            return "\(folder)/Season \(seasonNumber)/\(safe(match.title)) \(code)\(ext)"
        }
    }

    /// Makes a title safe as a file or folder name on macOS and on the
    /// network shares and other systems Jellyfin may run on.
    static func safe(_ name: String) -> String {
        var result = name.replacing(": ", with: " - ")
        for character in [":", "/", "\\"] {
            result = result.replacing(character, with: "-")
        }
        result.removeAll { "?*\"<>|".contains($0) || $0.isNewline }
        // No hidden files (leading dot), and no trailing dots or spaces,
        // which Windows and SMB shares reject.
        return result.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
    }

    private static func twoDigits(_ number: Int) -> String {
        number < 10 ? "0\(number)" : "\(number)"
    }
}
