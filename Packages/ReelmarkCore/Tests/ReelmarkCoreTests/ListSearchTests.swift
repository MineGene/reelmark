import XCTest

@testable import ReelmarkCore

final class ListSearchTests: XCTestCase {

    private let fields = ["Made.Up.Movie.2024.1080p.mkv", "Made Up Movie (2024)", ""]

    func testNothingTypedMatchesEverything() {
        XCTAssertTrue(ListSearch("").isEmpty)
        XCTAssertTrue(ListSearch("   ").isEmpty)
        XCTAssertTrue(ListSearch("").matches(fields))
    }

    func testIgnoresCaseAndAccents() {
        XCTAssertTrue(ListSearch("made up").matches(fields))
        XCTAssertTrue(ListSearch("MOVIE").matches(fields))
        XCTAssertTrue(ListSearch("Café").matches(["Made.Up.Cafe.2020.mkv"]))
    }

    func testEveryWordMustMatchInAnyOrderAndAnyField() {
        XCTAssertTrue(ListSearch("2024 movie").matches(fields))
        XCTAssertTrue(ListSearch("1080p (2024)").matches(fields))
        XCTAssertFalse(ListSearch("movie 2023").matches(fields))
    }

    func testSplitsOnAnyWhitespace() {
        XCTAssertEqual(ListSearch("  made\tup \n movie ").words, ["made", "up", "movie"])
    }
}
