import XCTest

/// Measures how much memory Reelmark uses with a long list, so changes to
/// the list can be compared ("the app runs on an 8 GB Mac alongside
/// Jellyfin", CLAUDE.md), using XCTest's memory metric: the peak physical
/// memory, as Activity Monitor counts it, appears in the UI tests log.
final class ReelmarkMemoryTests: XCTestCase {

    private static let itemCount = 300

    /// Launches with `count` made-up items and waits for the window,
    /// relaunching up to three times if it doesn't appear and logging which
    /// attempt worked. (Its absence was once caused by passing the count as a
    /// launch argument, which macOS read as a file to open.)
    @MainActor
    private func launch(withItems count: Int) throws -> XCUIApplication {
        continueAfterFailure = false
        for attempt in 1...3 {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing"]
            app.launchEnvironment["REELMARK_UI_TEST_ITEMS"] = "\(count)"
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

        // XCTest's own memory measurement, recorded in the test log as
        // "Memory Peak Physical" (kB) while the list scrolls to the bottom and
        // back, so every row has been drawn. (Reading another app's memory
        // directly isn't allowed from the sandboxed test runner in CI.)
        let list = app.scrollViews.firstMatch
        let options = XCTMeasureOptions()
        options.iterationCount = 1
        measure(metrics: [XCTMemoryMetric(application: app)], options: options) {
            for deltaY in [-5000.0, 5000.0] {
                for _ in 0..<10 { list.scroll(byDeltaX: 0, deltaY: deltaY) }
            }
        }
        XCTAssertEqual(app.state, .runningForeground, "Reelmark quit unexpectedly")
    }

    /// A very long list must stay usable: sorting, selecting everything and
    /// deleting it all should each finish promptly. Memory is measured while
    /// it sorts all 10,000 items one way and then the other.
    @MainActor
    func testTenThousandItemsStayResponsive() throws {
        let app = try launch(withItems: 10000)
        guard app.staticTexts["Made.Up.Show.S01E01.mkv"].waitForExistence(timeout: 30) else {
            print(app.debugDescription)
            return XCTFail("The made-up list didn't appear")
        }
        XCTAssertTrue(app.staticTexts["10,000 items"].waitForExistence(timeout: 10))

        let header = app.buttons["Downloaded File"].firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 10))
        let headerCentre = header.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let options = XCTMeasureOptions()
        options.iterationCount = 1
        measure(metrics: [XCTMemoryMetric(application: app)], options: options) {
            headerCentre.click()
            Thread.sleep(forTimeInterval: 1)  // so two clicks aren't read as a double-click
            headerCentre.click()
        }

        app.staticTexts.matching(NSPredicate(format: "value BEGINSWITH 'Made.Up.Show'")).firstMatch.click()
        app.typeKey("a", modifierFlags: .command)
        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(app.staticTexts["Drag Movies and TV Episodes Here"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.state, .runningForeground, "Reelmark quit unexpectedly")
    }
}
