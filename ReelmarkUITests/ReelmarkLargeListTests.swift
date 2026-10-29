import AppKit
import XCTest

/// Checks that a very long list stays usable: 3,000 made-up episodes load,
/// sort, and can all be selected and deleted without the window freezing or
/// the app quitting. The items come from REELMARK_UI_TEST_ITEMS (see
/// LibraryModel.forLaunch, Debug only).
///
/// 3,000 rows are dozens of screens, so work that grows with the square of
/// the list (what this guards against) still takes millions of steps. With
/// 10,000 rows these tests took about two minutes of scarce Mac runner time.
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
    func testThreeThousandItemsStayResponsive() throws {
        let app = try launch(withItems: 3000)
        guard app.staticTexts["Made.Up.Show.S01E01.mkv"].waitForExistence(timeout: 30) else {
            print(app.debugDescription)
            return XCTFail("The made-up list didn't appear")
        }
        XCTAssertTrue(app.staticTexts["3,000 items"].waitForExistence(timeout: 10))

        // Searching all 3,000 as you type: one episode is left, and
        // clearing the field brings back the whole list.
        app.typeKey("f", modifierFlags: .command)
        app.typeText("S01E01")
        XCTAssertTrue(
            app.staticTexts["1 of 3,000 items"].waitForExistence(timeout: 10), "Search was slow or wrong")
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(
            app.staticTexts["3,000 items"].waitForExistence(timeout: 10), "Clearing the search was slow")

        // Sort all 3,000 one way and then the other.
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

    /// A file added to a long list lands at the end, out of sight, so the
    /// list scrolls to it and selects it, as Finder does with pasted files.
    /// Only rows on screen exist for UI tests, so finding it proves it's
    /// visible, and Remove from List taking it away proves it's selected.
    @MainActor
    func testAddedFileIsShownAndSelected() throws {
        let name = "Made.Up.Added.Movie.2020.mkv"
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "ReelmarkReveal-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: name)
        try Data().write(to: file)

        let app = try launch(withItems: 300)
        XCTAssertTrue(app.staticTexts["300 items"].waitForExistence(timeout: 30))
        app.open(file)
        let added = app.staticTexts[name].firstMatch
        XCTAssertTrue(added.waitForExistence(timeout: 15), "The added file wasn't scrolled into view")
        // File › Remove from List acts on the selection wherever focus is.
        app.typeKey(.delete, modifierFlags: .command)
        let back = app.staticTexts["300 items"]
        XCTAssertTrue(back.waitForExistence(timeout: 10), "The added file wasn't selected")
        XCTAssertFalse(added.exists)

        // Opening a file can launch a second copy of the app, which
        // terminate() doesn't reach; quit every copy for the next tests.
        app.terminate()
        let copies = {
            NSRunningApplication.runningApplications(withBundleIdentifier: "com.minegene.reelmark")
        }
        copies().forEach { $0.forceTerminate() }
    }
}
