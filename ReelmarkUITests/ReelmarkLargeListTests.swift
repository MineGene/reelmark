import XCTest

/// Checks that a very long list stays usable: 10,000 made-up episodes load,
/// sort, and can all be selected and deleted without the window freezing or
/// the app quitting. The items come from REELMARK_UI_TEST_ITEMS (see
/// LibraryModel.forLaunch, Debug only).
final class ReelmarkLargeListTests: XCTestCase {

    /// Launches with `count` made-up items and waits for the window,
    /// relaunching up to three times if it doesn't appear.
    @MainActor
    private func launch(withItems count: Int) throws -> XCUIApplication {
        continueAfterFailure = false
        for attempt in 1...3 {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing"]
            // In the environment, not the arguments: macOS treats a bare
            // value like "10000" among an app's arguments as a file to open,
            // and then the window never appeared.
            app.launchEnvironment["REELMARK_UI_TEST_ITEMS"] = "\(count)"
            app.launch()
            if app.windows.firstMatch.waitForExistence(timeout: 15) { return app }
            print("No window on launch attempt \(attempt); relaunching")
            app.terminate()
        }
        throw NoWindow()
    }

    private struct NoWindow: Error, CustomStringConvertible {
        var description: String { "Reelmark's window never appeared in three launches" }
    }

    @MainActor
    func testTenThousandItemsStayResponsive() throws {
        let app = try launch(withItems: 10000)
        guard app.staticTexts["Made.Up.Show.S01E01.mkv"].waitForExistence(timeout: 30) else {
            print(app.debugDescription)
            return XCTFail("The made-up list didn't appear")
        }
        XCTAssertTrue(app.staticTexts["10,000 items"].waitForExistence(timeout: 10))

        // Sort all 10,000 one way and then the other.
        let header = app.buttons["Downloaded File"].firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 10))
        let headerCentre = header.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        headerCentre.click()
        Thread.sleep(forTimeInterval: 1)  // so two clicks aren't read as a double-click
        headerCentre.click()

        // Select everything and delete it: the empty window comes back.
        app.staticTexts.matching(NSPredicate(format: "value BEGINSWITH 'Made.Up.Show'")).firstMatch.click()
        app.typeKey("a", modifierFlags: .command)
        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(app.staticTexts["Drag Movies and TV Episodes Here"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.state, .runningForeground, "Reelmark quit unexpectedly")
    }
}
