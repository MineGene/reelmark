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

    /// True once `condition` holds, checking for up to 5 seconds: the list
    /// redraws a moment after a click, not instantly.
    @MainActor
    private func eventually(_ condition: () -> Bool) -> Bool {
        let deadline = Date.now.addingTimeInterval(5)
        while Date.now < deadline {
            if condition() { return true }
            RunLoop.current.run(until: .now.addingTimeInterval(0.2))
        }
        return condition()
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

    /// Files can be dropped anywhere in the window, empty or not, so the drop
    /// area must fill everything below the toolbar.
    @MainActor
    func testDropAreaFillsTheWindow() {
        for withItems in [false, true] {
            let app = launch(withItems: withItems)
            let window = app.windows.firstMatch
            let dropArea = app.descendants(matching: .any)["dropArea"].firstMatch
            XCTAssertTrue(dropArea.waitForExistence(timeout: 10))
            XCTAssertEqual(dropArea.frame.width, window.frame.width, accuracy: 2)
            // Everything but the toolbar, which is well under 120 points.
            XCTAssertGreaterThan(dropArea.frame.height, window.frame.height - 120)
            app.terminate()
        }
    }

    /// Xcode's accessibility audit (the checks Accessibility Inspector runs:
    /// descriptions, contrast, hit areas, text sizes and more) on the empty
    /// window and on a filled list. Every issue is listed, then the test
    /// fails once if there are any.
    ///
    /// Skipped, because they belong to macOS rather than to Reelmark:
    /// - contrast: Reelmark uses only the system's own text colours (no
    ///   custom colours, see CLAUDE.md), which macOS sets and adjusts for
    ///   Increase Contrast, so the audit's contrast results are Apple's;
    /// - containers macOS adds itself (SwiftUI's unnamed groups, the Touch Bar).
    @MainActor
    func testWindowPassesTheAccessibilityAudit() throws {
        var issues: [String] = []
        for withItems in [false, true] {
            let app = launch(withItems: withItems)
            if withItems {
                waitForItems(Self.all, in: app)
            } else {
                let emptyState = app.staticTexts["Drag Movies and TV Episodes Here"]
                XCTAssertTrue(emptyState.waitForExistence(timeout: 10))
            }
            try app.performAccessibilityAudit { issue in
                let element = issue.element
                let isContrast = issue.auditType == .contrast
                let isSystemContainer =
                    issue.auditType == .sufficientElementDescription
                    && [.group, .touchBar].contains(element?.elementType)
                    && (element?.identifier ?? "").isEmpty
                if !isContrast && !isSystemContainer {
                    let window = withItems ? "list" : "empty window"
                    issues.append("\(window): \(issue.compactDescription): \(element.map { "\($0)" } ?? "-")")
                }
                return true
            }
            app.terminate()
        }
        XCTAssertTrue(issues.isEmpty, "Accessibility audit:\n" + issues.joined(separator: "\n"))
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
    func testCommandDeleteRemovesTheSelectedItem() {
        let app = launch()
        waitForItems(Self.all, in: app)
        item(Self.unmatched, in: app).click()
        app.typeKey(.delete, modifierFlags: .command)
        waitForItems([Self.ready] + Self.copied, in: app)
        assertStillRunning(app)
    }

    @MainActor
    func testCommandROpensSearchAgainForTheSelectedItem() {
        let app = launch()
        waitForItems(Self.all, in: app)
        item(Self.unmatched, in: app).click()
        app.typeKey("r", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["Search The Movie Database"].waitForExistence(timeout: 10))
        // Command-Delete must not reach the list while the sheet's text field is in use.
        app.typeKey(.delete, modifierFlags: .command)
        // Escape is Cancel. (Clicking "Cancel" can hit the Touch Bar's copy
        // of the button, which UI tests can't click.)
        app.typeKey(.escape, modifierFlags: [])
        let title = app.staticTexts["Search The Movie Database"]
        XCTAssertTrue(eventually { !title.exists }, "The sheet didn't close")
        waitForItems(Self.all, in: app)
        assertStillRunning(app)
    }

    @MainActor
    func testFileMenuOffersTheListCommands() {
        let app = launch()
        waitForItems(Self.all, in: app)
        item(Self.ready, in: app).click()
        app.menuBars.menuBarItems["File"].click()
        for name in [
            "Add Files…", "Copy to Library", "Search Again…", "Show in Finder", "Remove from List",
            "Clear List",
        ] {
            XCTAssertTrue(app.menuItems[name].exists, "No \(name) in the File menu")
        }
        XCTAssertTrue(app.menuItems["Copy to Library"].isEnabled)
        app.menuItems["Clear List"].click()
        XCTAssertTrue(app.staticTexts["Drag Movies and TV Episodes Here"].waitForExistence(timeout: 10))
        assertStillRunning(app)
    }

    @MainActor
    func testRightClickOffersShowInFinder() {
        let app = launch()
        waitForItems(Self.all, in: app)
        item(Self.ready, in: app).rightClick()
        XCTAssertTrue(app.menuItems["Show in Finder"].waitForExistence(timeout: 10))
        app.typeKey(.escape, modifierFlags: [])
        assertStillRunning(app)
    }

    @MainActor
    func testClearEmptiesTheWholeList() {
        let app = launch()
        waitForItems(Self.all, in: app)
        app.buttons["Clear"].firstMatch.click()
        XCTAssertTrue(app.staticTexts["Drag Movies and TV Episodes Here"].waitForExistence(timeout: 10))
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
        XCTAssertTrue(eventually { another.frame.minY < ready.frame.minY }, "Not sorted A to Z")
        Thread.sleep(forTimeInterval: 1)  // so two clicks aren't read as a double-click
        headerCentre.click()  // Z to A
        XCTAssertTrue(eventually { ready.frame.minY < another.frame.minY }, "Not sorted Z to A")
        assertStillRunning(app)
    }
}
