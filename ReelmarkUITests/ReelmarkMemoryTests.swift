import AppKit
import Darwin
import XCTest

/// Measures how much memory Reelmark uses with a long list, so changes to
/// the list can be compared ("the app runs on an 8 GB Mac alongside
/// Jellyfin", CLAUDE.md). It reports the same "physical footprint" figure
/// Activity Monitor shows as Memory, as a notice on the CI run.
final class ReelmarkMemoryTests: XCTestCase {

    private static let itemCount = 300

    /// Launches with `count` made-up items and waits for the window. These
    /// tests run first, and on a fresh CI machine the first launches have
    /// come up with no window at all, so it relaunches (up to three times)
    /// and logs which attempt worked.
    @MainActor
    private func launch(withItems count: Int) throws -> XCUIApplication {
        continueAfterFailure = false
        for attempt in 1...3 {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing", "-ui-testing-items", "\(count)"]
            app.launch()
            if app.windows.firstMatch.waitForExistence(timeout: 15) {
                print("Reelmark's window appeared on launch attempt \(attempt)")
                return app
            }
            print("No window on launch attempt \(attempt); relaunching")
            app.terminate()
        }
        throw NoWindow()
    }

    private struct NoWindow: Error, CustomStringConvertible {
        var description: String { "Reelmark's window never appeared in three launches" }
    }

    @MainActor
    func testFootprintWithALongList() throws {
        let app = try launch(withItems: Self.itemCount)
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
