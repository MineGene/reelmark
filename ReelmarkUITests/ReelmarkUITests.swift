import XCTest

/// Launches the real app and uses it the way a person would, so anything
/// that crashes or breaks the window (like the Delete and Clear crashes in
/// 0.1.0) fails CI before it can be released.
///
/// The app is launched with "-ui-testing", a Debug-only switch that fills the
/// list with four made-up items (see LibraryModel.forLaunch): one ready to
/// copy, two already in the library and one with no match. No real files are
/// touched and nothing goes online.
final class ReelmarkUITests: XCTestCase {

    @MainActor
    private func launch(withItems: Bool = true) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = withItems ? ["-ui-testing"] : []
        app.launch()
        return app
    }

    @MainActor
    private func rows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.tables.firstMatch.tableRows
    }

    /// Waits up to 10 seconds for the list to have `count` rows.
    @MainActor
    private func waitForRows(_ count: Int, in app: XCUIApplication) {
        let predicate = NSPredicate(format: "count == %d", count)
        wait(for: [expectation(for: predicate, evaluatedWith: rows(app))], timeout: 10)
    }

    @MainActor
    private func assertStillRunning(_ app: XCUIApplication) {
        XCTAssertEqual(app.state, .runningForeground, "Reelmark quit unexpectedly")
    }

    @MainActor
    func testEmptyWindowExplainsDragAndDrop() {
        let app = launch(withItems: false)
        XCTAssertTrue(app.staticTexts["Drag Movies and TV Episodes Here"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Add Files…"].exists)
    }

    @MainActor
    func testListShowsEveryItem() {
        let app = launch()
        waitForRows(4, in: app)
        XCTAssertTrue(app.staticTexts["Ready.Movie.2020.mkv"].exists)
    }

    @MainActor
    func testDeleteKeyRemovesTheSelectedItem() {
        let app = launch()
        waitForRows(4, in: app)
        rows(app).element(boundBy: 0).click()
        app.typeKey(.delete, modifierFlags: [])
        waitForRows(3, in: app)
        assertStillRunning(app)
    }

    @MainActor
    func testClearRemovesItemsAlreadyInTheLibrary() {
        let app = launch()
        waitForRows(4, in: app)
        app.buttons["Clear"].firstMatch.click()
        waitForRows(2, in: app)
        assertStillRunning(app)
    }

    @MainActor
    func testRemovingEverythingShowsTheEmptyWindow() {
        let app = launch()
        waitForRows(4, in: app)
        rows(app).element(boundBy: 0).click()
        app.typeKey("a", modifierFlags: .command)
        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(app.staticTexts["Drag Movies and TV Episodes Here"].waitForExistence(timeout: 10))
        assertStillRunning(app)
    }

    @MainActor
    func testCopyWithoutLibraryFoldersSaysWhatToDo() {
        let app = launch()
        waitForRows(4, in: app)
        app.buttons["Copy 1 to Library"].firstMatch.click()
        let message = app.staticTexts["Choose a Movies folder in Settings."]
        XCTAssertTrue(message.waitForExistence(timeout: 10))
        assertStillRunning(app)
    }

    @MainActor
    func testSettingsOpen() {
        let app = launch()
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["Built in"].waitForExistence(timeout: 10))
        assertStillRunning(app)
    }

    @MainActor
    func testAboutWindowOpens() {
        let app = launch()
        app.menuBars.menuBarItems["Reelmark"].click()
        app.menuItems["About Reelmark"].click()
        let version = app.staticTexts.matching(NSPredicate(format: "value BEGINSWITH 'Version'")).firstMatch
        XCTAssertTrue(version.waitForExistence(timeout: 10))
        assertStillRunning(app)
    }
}
