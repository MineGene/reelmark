import XCTest

/// Launches the real app and uses it the way a person would, so anything
/// that crashes or breaks the window (like the Delete and Clear crashes in
/// 0.1.0) fails CI before it can be released.
///
/// The app is launched with "-ui-testing", a Debug-only switch that fills the
/// list with four made-up items (see LibraryModel.forLaunch): one ready to
/// copy, two already in the library and one with no match. No real files are
/// touched and nothing goes online.
///
/// Items are found by their file names rather than by counting table rows:
/// SwiftUI's Table doesn't promise how its rows appear to accessibility.
final class ReelmarkUITests: XCTestCase {

    private static let ready = "Ready.Movie.2020.mkv"
    private static let copied = ["Copied.Movie.2020.mkv", "Another.Copied.Movie.2020.mkv"]
    private static let unmatched = "Unknown.Thing.2020.mkv"
    private static let all = [ready] + copied + [unmatched]

    @MainActor
    private func launch(withItems: Bool = true) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = withItems ? ["-ui-testing"] : []
        app.launch()
        return app
    }

    @MainActor
    private func item(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts[name].firstMatch
    }

    /// Waits up to 10 seconds until exactly `names` are listed. On failure the
    /// window's accessibility tree is printed to the log to show why.
    @MainActor
    private func waitForItems(_ names: [String], in app: XCUIApplication) {
        let expectations = Self.all.map { name in
            expectation(
                for: NSPredicate(format: "exists == %@", NSNumber(value: names.contains(name))),
                evaluatedWith: item(name, in: app))
        }
        if XCTWaiter().wait(for: expectations, timeout: 10) != .completed {
            print(app.debugDescription)
            XCTFail("Expected the list to show exactly \(names)")
        }
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
        waitForItems(Self.all, in: app)
    }

    @MainActor
    func testDeleteKeyRemovesTheSelectedItem() {
        let app = launch()
        waitForItems(Self.all, in: app)
        item(Self.unmatched, in: app).click()
        app.typeKey(.delete, modifierFlags: [])
        waitForItems([Self.ready] + Self.copied, in: app)
        assertStillRunning(app)
    }

    @MainActor
    func testClearRemovesItemsAlreadyInTheLibrary() {
        let app = launch()
        waitForItems(Self.all, in: app)
        app.buttons["Clear"].firstMatch.click()
        waitForItems([Self.ready, Self.unmatched], in: app)
        assertStillRunning(app)
    }

    @MainActor
    func testRemovingEverythingShowsTheEmptyWindow() {
        let app = launch()
        waitForItems(Self.all, in: app)
        item(Self.ready, in: app).click()
        app.typeKey("a", modifierFlags: .command)
        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(app.staticTexts["Drag Movies and TV Episodes Here"].waitForExistence(timeout: 10))
        assertStillRunning(app)
    }

    @MainActor
    func testCopyWithoutLibraryFoldersSaysWhatToDo() {
        let app = launch()
        waitForItems(Self.all, in: app)
        app.buttons["Copy 1 to Library"].firstMatch.click()
        let message = app.staticTexts["Choose a Movies folder in Settings."].firstMatch
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

    @MainActor
    func testClickingAColumnHeaderSortsBothWays() {
        let app = launch()
        waitForItems(Self.all, in: app)
        let header = app.buttons["Downloaded File"].firstMatch
        guard header.waitForExistence(timeout: 10) else {
            print(app.debugDescription)
            return XCTFail("No Downloaded File column header")
        }
        // Listed in order: Ready…, Copied…, Another.Copied…, Unknown…
        let ready = item(Self.ready, in: app)
        let another = item("Another.Copied.Movie.2020.mkv", in: app)

        // Table header buttons report themselves as not hittable to UI
        // tests even when visible, so click the middle of the header itself.
        let headerCentre = header.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        headerCentre.click()  // A to Z: Another.Copied… comes before Ready…
        XCTAssertLessThan(another.frame.minY, ready.frame.minY)
        headerCentre.click()  // Z to A
        XCTAssertLessThan(ready.frame.minY, another.frame.minY)
        assertStillRunning(app)
    }
}
