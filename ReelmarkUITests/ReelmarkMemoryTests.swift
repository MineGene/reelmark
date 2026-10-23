import AppKit
import Darwin
import XCTest

/// Measures how much memory Reelmark uses with a long list, so changes to
/// the list can be compared ("the app runs on an 8 GB Mac alongside
/// Jellyfin", CLAUDE.md). It reports the same "physical footprint" figure
/// Activity Monitor shows as Memory, as a notice on the CI run.
final class ReelmarkMemoryTests: XCTestCase {

    private static let itemCount = 300

    @MainActor
    func testFootprintWithALongList() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-items", "\(Self.itemCount)"]
        app.launch()
        guard app.staticTexts["Made.Up.Show.S01E01.mkv"].waitForExistence(timeout: 20) else {
            print(app.debugDescription)  // shows in the log what the window had instead
            return XCTFail("The made-up list didn't appear")
        }

        // Scroll the whole list down and back up, so every row has been drawn.
        let list = app.scrollViews.firstMatch
        for deltaY in [-2000.0, 2000.0] {
            for _ in 0..<30 { list.scroll(byDeltaX: 0, deltaY: deltaY) }
        }
        XCTAssertEqual(app.state, .runningForeground, "Reelmark quit unexpectedly")

        let footprint = try XCTUnwrap(Self.footprint(ofBundle: "com.minegene.reelmark"))
        let megabytes = String(format: "%.1f", Double(footprint) / 1_048_576)
        // A GitHub Actions notice, so the number shows on the check itself.
        print("::notice title=Memory::Reelmark footprint with \(Self.itemCount) items: \(megabytes) MB")
    }

    /// A very long list must stay usable: sorting, selecting everything and
    /// deleting it all should each finish promptly.
    @MainActor
    func testTenThousandItemsStayResponsive() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-items", "10000"]
        app.launch()
        let first = app.staticTexts["Made.Up.Show.S01E01.1080p.WEB.mkv"]
        XCTAssertTrue(first.waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["10,000 items"].waitForExistence(timeout: 10))

        let header = app.buttons["Downloaded File"].firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 10))
        header.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        header.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()

        if let footprint = Self.footprint(ofBundle: "com.minegene.reelmark") {
            let megabytes = String(format: "%.1f", Double(footprint) / 1_048_576)
            print("::notice title=Memory::Reelmark footprint with 10000 items: \(megabytes) MB")
        }

        app.staticTexts.matching(NSPredicate(format: "value BEGINSWITH 'Made.Up.Show'")).firstMatch.click()
        app.typeKey("a", modifierFlags: .command)
        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(app.staticTexts["Drag Movies and TV Episodes Here"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.state, .runningForeground, "Reelmark quit unexpectedly")
    }

    /// The app's physical footprint in bytes, as Activity Monitor reports it.
    private static func footprint(ofBundle bundle: String) -> UInt64? {
        guard let pid = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first?
            .processIdentifier
        else { return nil }
        var info = rusage_info_v6()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V6, $0)
            }
        }
        return result == 0 ? info.ri_phys_footprint : nil
    }
}
