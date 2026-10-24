# UI tests

These tests launch a Debug build of Reelmark with `-ui-testing`, which fills the list with made-up items (`LibraryModel.forLaunch`, Debug only), and use the window the way a person would. Every window change needs one, especially anything that removes or changes rows. They run only on GitHub's macOS runners (the *UI tests* check).

Things learned the hard way on those runners:

- Pass test settings, such as a list size, through the launch environment (`REELMARK_UI_TEST_ITEMS`), never as launch arguments: macOS reads a bare number as a file to open, and the window never appears.
- XCUITest calls table headers not hittable: click them by coordinate, and pause a second between two clicks so they aren't read as a double-click.
- The runners are slow and queue jobs: give every wait a timeout, and expect checks to take a while.
- A test that opens a file with the app (`app.open`) can make macOS launch a second copy. Quit every copy by bundle identifier afterwards (see `testOpeningAVideoWithReelmarkAddsIt`).
- Dragging a window corner never resizes the window on the runners, so window-size changes stay hand checks.
- The accessibility audit flags table cells that are hidden from accessibility, or made elements without a role: name every cell and give hand-made elements a role.
- A status icon shows up twice in its row (the cell, and the image inside it), though VoiceOver reads it once: count statuses by row, not by element (see `testListReadsColumnsAndStatusesToVoiceOver`).
- Items are found by their file names rather than by counting table rows, since SwiftUI and AppKit don't promise how rows appear to accessibility.
