import XCTest

@testable import ReelmarkCore

final class JellyfinNamingTests: XCTestCase {

    func testMovie() {
        let parsed = ParsedName(title: "Dune Part Two", year: 2024, kind: .movie)
        let match = Match(id: 693134, kind: .movie, title: "Dune: Part Two", year: 2024)
        XCTAssertEqual(
            JellyfinNaming.relativePath(for: parsed, match: match, fileExtension: "MKV"),
            "Dune - Part Two (2024) [tmdbid-693134]/Dune - Part Two (2024) [tmdbid-693134].mkv")
    }

    func testEpisode() {
        let parsed = ParsedName(title: "Severance", kind: .episode(season: 1, episodes: [2]))
        let match = Match(id: 95396, kind: .show, title: "Severance", year: 2022)
        XCTAssertEqual(
            JellyfinNaming.relativePath(for: parsed, match: match, fileExtension: "mkv"),
            "Severance (2022) [tmdbid-95396]/Season 01/Severance S01E02.mkv")
    }

    func testMultiEpisodeAndSpecials() {
        let match = Match(id: 1, kind: .show, title: "Show", year: nil)
        XCTAssertEqual(
            JellyfinNaming.relativePath(
                for: ParsedName(title: "Show", kind: .episode(season: 1, episodes: [1, 2])),
                match: match, fileExtension: "mp4"),
            "Show [tmdbid-1]/Season 01/Show S01E01-E02.mp4")
        XCTAssertEqual(
            JellyfinNaming.relativePath(
                for: ParsedName(title: "Show", kind: .episode(season: 0, episodes: [12])),
                match: match, fileExtension: "mp4"),
            "Show [tmdbid-1]/Season 00/Show S00E12.mp4")
    }

    func testUnsafeCharacters() {
        XCTAssertEqual(JellyfinNaming.safe("AC/DC: Live? \"Now\" <here>|"), "AC-DC - Live Now here")
        XCTAssertEqual(JellyfinNaming.safe(".hidden name..."), "hidden name")
    }
}
