import Foundation

/// What a downloaded file's name says it is: a title, maybe a year, and for
/// TV episodes the season and episode numbers. Nothing here is looked up
/// online; it is the best guess from the name alone.
public struct ParsedName: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case movie
        /// `episodes` holds one number, or the first and last of a
        /// multi-episode file (S01E01-E02).
        case episode(season: Int, episodes: [Int])
    }

    public var title: String
    public var year: Int?
    public var kind: Kind

    public init(title: String, year: Int? = nil, kind: Kind) {
        self.title = title
        self.year = year
        self.kind = kind
    }

    public var isEpisode: Bool {
        if case .episode = kind { return true }
        return false
    }
}

/// Turns scene-style release names into a title, year and episode number.
///
///     The.Last.of.Us.S02E03.1080p.WEB.H264-GROUP.mkv → "The Last of Us", S2 E3
///     Dune.Part.Two.2024.2160p.UHD.BluRay.x265.mkv    → "Dune Part Two" (2024)
///
/// Deliberately simple: a few patterns that cover the vast majority of
/// names. Anything it gets wrong can be corrected by picking another match.
public enum ReleaseNameParser {

    /// - Parameters:
    ///   - fileName: the file's name, with or without extension.
    ///   - parentFolder: the name of the folder the file sits in. Used when
    ///     the file name has no title of its own (for example `S01E02.mkv`
    ///     inside `Severance Season 1`).
    ///   - currentYear: years later than next year are treated as part of
    ///     the title, not as a release year (`Blade Runner 2049`).
    public static func parse(
        fileName: String,
        parentFolder: String? = nil,
        currentYear: Int = Calendar.current.component(.year, from: .now)
    ) -> ParsedName {
        let text = clean((fileName as NSString).deletingPathExtension)
        var result =
            parseEpisode(text, currentYear: currentYear) ?? parseMovie(text, currentYear: currentYear)

        if result.title.isEmpty, let parentFolder {
            let folder = parseMovie(cutSeasonMarker(clean(parentFolder)), currentYear: currentYear)
            result.title = folder.title
            result.year = result.year ?? folder.year
        }
        return result
    }

    // MARK: - Steps

    /// Removes [group tags] and {tags}, and turns dots, underscores and
    /// brackets into spaces.
    static func clean(_ name: String) -> String {
        name
            .replacing(/\[[^\]]*\]|\{[^}]*\}/, with: " ")
            .replacing(/[._()]/, with: " ")
            .replacing(/\s+/, with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// `Show Name S01E02…`, `Show Name S01E01-E02…` or `Show Name 1x02…`.
    static func parseEpisode(_ text: String, currentYear: Int) -> ParsedName? {
        let standard = /\bS(\d{1,2}) ?E(\d{1,3})((?:-?E\d{1,3}|-\d{1,3}(?!\d))*)/.ignoresCase()
        let crossed = /\b(\d{1,2})x(\d{2,3})\b/.ignoresCase()

        let season: Int
        var episodes: [Int]
        let titleEnd: String.Index

        if let match = text.firstMatch(of: standard) {
            season = Int(match.output.1) ?? 0
            episodes = [Int(match.output.2) ?? 0]
            // Any further episode numbers of a multi-episode file. Only the
            // last one matters: Jellyfin names the range by first and last.
            let more = match.output.3.matches(of: /\d+/).compactMap { Int($0.output) }
            if let last = more.last { episodes.append(last) }
            titleEnd = match.range.lowerBound
        } else if let match = text.firstMatch(of: crossed) {
            season = Int(match.output.1) ?? 0
            episodes = [Int(match.output.2) ?? 0]
            titleEnd = match.range.lowerBound
        } else {
            return nil
        }

        let (title, year) = splitTrailingYear(trimTitle(String(text[..<titleEnd])), currentYear: currentYear)
        return ParsedName(title: title, year: year, kind: .episode(season: season, episodes: episodes))
    }

    /// `Movie Name 2019 1080p…` → title before the last plausible year.
    /// Without a year, the title ends at the first quality tag.
    static func parseMovie(_ text: String, currentYear: Int) -> ParsedName {
        var title = text
        var year: Int?

        // A year at the very start is part of the title ("2012", "1917").
        let years = text.matches(of: /\b(19\d{2}|20\d{2})\b/).filter {
            $0.range.lowerBound > text.startIndex && (Int($0.output.1) ?? 0) <= currentYear + 1
        }
        if let last = years.last {
            title = String(text[..<last.range.lowerBound])
            year = Int(last.output.1)
        }

        if let tag = title.firstMatch(of: qualityTag), tag.range.lowerBound > title.startIndex {
            title = String(title[..<tag.range.lowerBound])
        }
        return ParsedName(title: trimTitle(title), year: year, kind: .movie)
    }

    // MARK: - Helpers

    /// Words that only ever appear in the technical part of a release name.
    /// (Built on each use: `Regex` isn't `Sendable`, so it can't be a stored
    /// static under Swift 6's concurrency checking. Building one is cheap.)
    private static var qualityTag: Regex<Substring> {
        // swift-format-ignore
        /\b(?:2160p|1080p|1080i|720p|576p|480p|4k|uhd|blu-?ray|bdrip|brrip|remux|web-?dl|webrip|hdtv|dvdrip|hdrip|x26[45]|h ?26[45]|hevc|avc|hdr10|hdr|dolby|atmos|aac|ac3|dts|proper|repack|extended|unrated|imax|10bit)\b/
            .ignoresCase()
    }

    /// "Severance Season 1 1080p" → "Severance 1080p", so a folder name can
    /// supply a show's title.
    private static func cutSeasonMarker(_ text: String) -> String {
        if let marker = text.firstMatch(of: /\b(?:S\d{1,2}(?:E\d{1,3})?|Season ?\d{1,2})\b/.ignoresCase()) {
            return String(text[..<marker.range.lowerBound])
        }
        return text
    }

    /// "Doctor Who 2005" → ("Doctor Who", 2005), used for shows that share
    /// a name with an older one.
    private static func splitTrailingYear(_ title: String, currentYear: Int) -> (String, Int?) {
        if let match = title.firstMatch(of: /^(.*\S) (19\d{2}|20\d{2})$/),
            let year = Int(match.output.2), year <= currentYear + 1
        {
            return (String(match.output.1), year)
        }
        return (title, nil)
    }

    private static func trimTitle(_ title: String) -> String {
        title.trimmingCharacters(in: CharacterSet(charactersIn: " -–"))
    }
}
