import XCTest

@testable import ReelmarkCore

/// Real-world-style release names (invented, not taken from anyone's files).
final class ReleaseNameParserTests: XCTestCase {

    private func parse(_ name: String, folder: String? = nil, above: String? = nil) -> ParsedName {
        ReleaseNameParser.parse(
            fileName: name, parentFolder: folder, grandparentFolder: above, currentYear: 2026)
    }

    // MARK: Episodes

    func testStandardEpisode() {
        XCTAssertEqual(
            parse("The.Last.of.Us.S02E03.1080p.WEB.H264-GROUP.mkv"),
            ParsedName(title: "The Last of Us", kind: .episode(season: 2, episodes: [3])))
    }

    func testLowercaseAndSpaces() {
        XCTAssertEqual(
            parse("severance s01e09 720p.mp4"),
            ParsedName(title: "severance", kind: .episode(season: 1, episodes: [9])))
    }

    func testDashSeparatedWithEpisodeTitle() {
        XCTAssertEqual(
            parse("Slow Horses - S04E01 - Identity Theft.mkv"),
            ParsedName(title: "Slow Horses", kind: .episode(season: 4, episodes: [1])))
    }

    func testMultiEpisode() {
        XCTAssertEqual(
            parse("Show.Name.S01E01E02.mkv"),
            ParsedName(title: "Show Name", kind: .episode(season: 1, episodes: [1, 2])))
        XCTAssertEqual(
            parse("Show.Name.S01E01-E03.1080p.mkv"),
            ParsedName(title: "Show Name", kind: .episode(season: 1, episodes: [1, 3])))
    }

    func testResolutionAfterEpisodeIsNotAnotherEpisode() {
        XCTAssertEqual(
            parse("Show.Name.S01E01-1080p.mkv"),
            ParsedName(title: "Show Name", kind: .episode(season: 1, episodes: [1])))
    }

    func testCrossedFormat() {
        XCTAssertEqual(
            parse("Taskmaster.12x05.HDTV.mkv"),
            ParsedName(title: "Taskmaster", kind: .episode(season: 12, episodes: [5])))
    }

    func testResolutionIsNotCrossedFormat() {
        XCTAssertEqual(parse("Some.Movie.2019.1920x1080.mkv").kind, .movie)
    }

    func testShowYearIsSplitOff() {
        XCTAssertEqual(
            parse("Doctor.Who.2005.S01E01.mkv"),
            ParsedName(title: "Doctor Who", year: 2005, kind: .episode(season: 1, episodes: [1])))
    }

    func testGroupTagIsRemoved() {
        XCTAssertEqual(
            parse("[SomeGroup] Frieren - S01E05 [1080p].mkv"),
            ParsedName(title: "Frieren", kind: .episode(season: 1, episodes: [5])))
    }

    func testTitleFromFolder() {
        XCTAssertEqual(
            parse("S01E02.mkv", folder: "Severance.Season.1.1080p"),
            ParsedName(title: "Severance", kind: .episode(season: 1, episodes: [2])))
        XCTAssertEqual(
            parse("S02E01.mkv", folder: "Andor.S02.2025.2160p"),
            ParsedName(title: "Andor", kind: .episode(season: 2, episodes: [1])))
    }

    func testShowNameFromFolderAboveASeasonFolder() {
        // Severance/Season 2/S02E03.mkv
        XCTAssertEqual(
            parse("S02E03.mkv", folder: "Season 2", above: "Severance"),
            ParsedName(title: "Severance", kind: .episode(season: 2, episodes: [3])))
        // Severance (2022)/Season 02/S02E03.mkv keeps the show's year too.
        XCTAssertEqual(
            parse("S02E03.mkv", folder: "Season 02", above: "Severance (2022)"),
            ParsedName(title: "Severance", year: 2022, kind: .episode(season: 2, episodes: [3])))
    }

    func testSeasonFromFolderWhenNameHasOnlyAnEpisodeNumber() {
        let expected = ParsedName(title: "Severance", kind: .episode(season: 2, episodes: [3]))
        XCTAssertEqual(parse("Episode 03.mkv", folder: "Season 2", above: "Severance"), expected)
        XCTAssertEqual(parse("Ep 3.mkv", folder: "Season 02", above: "Severance"), expected)
        XCTAssertEqual(parse("E03.mkv", folder: "Severance S02"), expected)
        XCTAssertEqual(parse("03 - The Outie Sees.mkv", folder: "Season 2", above: "Severance"), expected)
        XCTAssertEqual(parse("Severance E03.mkv", folder: "Season 2"), expected)
    }

    func testBareNumberOutsideASeasonFolderIsNotAnEpisode() {
        XCTAssertFalse(parse("03 - Something.mkv", folder: "Downloads").isEpisode)
        XCTAssertFalse(parse("Episode 03.mkv").isEpisode)
    }

    // MARK: Movies

    func testMovieWithYear() {
        XCTAssertEqual(
            parse("Dune.Part.Two.2024.2160p.UHD.BluRay.x265-GROUP.mkv"),
            ParsedName(title: "Dune Part Two", year: 2024, kind: .movie))
    }

    func testYearInBrackets() {
        XCTAssertEqual(
            parse("Past Lives (2023).mp4"),
            ParsedName(title: "Past Lives", year: 2023, kind: .movie))
    }

    func testTitleStartingWithAYear() {
        XCTAssertEqual(parse("1917.2019.1080p.mkv"), ParsedName(title: "1917", year: 2019, kind: .movie))
        XCTAssertEqual(parse("2012.mkv"), ParsedName(title: "2012", kind: .movie))
    }

    func testFutureNumberIsPartOfTitle() {
        XCTAssertEqual(
            parse("Blade.Runner.2049.2017.1080p.mkv"),
            ParsedName(title: "Blade Runner 2049", year: 2017, kind: .movie))
    }

    func testMovieWithoutYearStopsAtQualityTag() {
        XCTAssertEqual(
            parse("Some.Film.1080p.WEB-DL.DDP5.1.mkv"),
            ParsedName(title: "Some Film", kind: .movie))
    }

    func testPlainName() {
        XCTAssertEqual(parse("Paddington.mkv"), ParsedName(title: "Paddington", kind: .movie))
    }
}
