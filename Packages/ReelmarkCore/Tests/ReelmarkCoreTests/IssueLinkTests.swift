import XCTest

@testable import ReelmarkCore

final class IssueLinkTests: XCTestCase {

    func testUsesTheIssueFormAndFillsItsFields() throws {
        let fields = [("version", "0.1.12 (12)"), ("macos", "26.1, Mac16,1")]
        let url = try XCTUnwrap(IssueLink.url(.bug, fields: fields.map { (id: $0.0, value: $0.1) }))
        let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(parts.host, "github.com")
        XCTAssertEqual(parts.path, "/MineGene/reelmark/issues/new")
        XCTAssertEqual(
            parts.queryItems,
            [
                URLQueryItem(name: "template", value: "bug.yml"),
                URLQueryItem(name: "version", value: "0.1.12 (12)"),
                URLQueryItem(name: "macos", value: "26.1, Mac16,1"),
            ])
    }

    func testPlusSignsSurviveAsPlusSigns() throws {
        let url = try XCTUnwrap(IssueLink.url(.feature, fields: [("diagnostics", "C++ & more")]))
        XCTAssertTrue(url.absoluteString.contains("C%2B%2B"))
        let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(parts.queryItems?.last?.value, "C++ & more")
    }

    func testLongValuesAreCutToFitAnAddress() throws {
        let long = String(repeating: "a", count: 50_000)
        let url = try XCTUnwrap(IssueLink.url(.bug, fields: [("diagnostics", long)]))
        XCTAssertLessThanOrEqual(url.absoluteString.count, IssueLink.maxLength + 200)
    }
}
