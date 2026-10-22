import XCTest

@testable import ReelmarkCore

/// Decoding of saved, trimmed-down TMDB responses. No network in tests.
final class TMDBDecodingTests: XCTestCase {

    func testMovieResults() throws {
        let json = """
            {"page":1,"results":[
              {"id":693134,"title":"Dune: Part Two","release_date":"2024-02-27","overview":"Paul…","adult":false},
              {"id":42,"title":"Untitled","release_date":"","overview":null},
              {"id":43,"title":"","release_date":"2020-01-01"}
            ],"total_results":3}
            """
        let matches = try TMDBClient.decodeSearch(Data(json.utf8), kind: .movie)
        XCTAssertEqual(
            matches,
            [
                Match(id: 693134, kind: .movie, title: "Dune: Part Two", year: 2024, overview: "Paul…"),
                Match(id: 42, kind: .movie, title: "Untitled", year: nil),
            ])
    }

    func testShowResults() throws {
        let json = """
            {"results":[{"id":95396,"name":"Severance","first_air_date":"2022-02-17","overview":"Mark…"}]}
            """
        let matches = try TMDBClient.decodeSearch(Data(json.utf8), kind: .show)
        XCTAssertEqual(matches.first?.title, "Severance")
        XCTAssertEqual(matches.first?.year, 2022)
        XCTAssertEqual(matches.first?.kind, .show)
    }

    func testKeepsAtMostSixResults() throws {
        let results = (1...20).map { #"{"id":\#($0),"title":"T\#($0)"}"# }.joined(separator: ",")
        let matches = try TMDBClient.decodeSearch(Data(#"{"results":[\#(results)]}"#.utf8), kind: .movie)
        XCTAssertEqual(matches.count, TMDBClient.maxResults)
    }
}
