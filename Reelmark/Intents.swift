import AppIntents

// Actions for the Shortcuts app, Spotlight and Siri (Apple's App Intents).
// They run inside Reelmark, on the same list as the window, so they send
// nothing more than the window does: only a title and year to TMDB.

/// Adds files or download folders to the list, as dragging them in does.
struct AddFilesIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Files to Reelmark"
    // One string literal (a multi-line one, joined with backslashes):
    // IntentDescription takes a localizable literal, not a built String.
    static let description = IntentDescription(
        """
        Adds video files or download folders to Reelmark's list \
        and looks each one up on The Movie Database.
        """)
    static let openAppWhenRun = true

    @Parameter(title: "Files or Folders", supportedContentTypes: [.movie, .folder])
    var files: [IntentFile]

    @MainActor
    func perform() async throws -> some IntentResult {
        LibraryModel.shared.add(files.compactMap(\.fileURL))
        return .result()
    }
}

/// Files every matched item, as the Copy (or Move) to Library button does.
/// It first waits for files still being searched or looked up, so a
/// Shortcut can add files and then run this straight away.
struct FileMatchedItemsIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Matched Files to Library"
    static let description = IntentDescription(
        """
        Copies or moves every matched file in Reelmark's list into your Jellyfin library, \
        following the Copy or Move choice in Settings.
        """)
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = LibraryModel.shared
        await model.waitUntilMatched()
        let before = model.items.count(where: { $0.status == .done })
        await model.renameReady(undoManager: nil)
        let filed = model.items.count(where: { $0.status == .done }) - before
        let attention = model.items.count(where: { $0.statusRank == 0 })
        let summary = attention == 0 ? "" : " \(attention) need attention in Reelmark."
        return .result(dialog: "\(filed) added to your library.\(summary)")
    }
}
