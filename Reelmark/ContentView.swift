import AppKit
import ReelmarkCore
import SwiftUI

/// The main window: drag files in, check the matches, press Copy to Library.
/// Standard SwiftUI controls only, so the window follows macOS's own design
/// (materials, toolbar, light and dark, accessibility) without custom styling.
struct ContentView: View {
    @Environment(LibraryModel.self) private var model
    @Environment(\.undoManager) private var undoManager
    @State private var selection = Set<LibraryModel.Item.ID>()
    @State private var searchingFor: LibraryModel.Item.ID?
    @State private var searchTitle = ""

    var body: some View {
        @Bindable var model = model
        Group {
            if model.items.isEmpty {
                EmptyState(model: model)
            } else {
                ItemList(model: model, selection: $selection, onSearch: searchAgain)
            }
        }
        // Fill the window, so a drop anywhere in it counts, not just on the
        // empty state's text in the middle.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dropArea")
        .accessibilityLabel(model.items.isEmpty ? "Drop files here" : "Files to rename")
        .toolbar { toolbar }
        .navigationSubtitle(itemCount)
        // VoiceOver says when slow work finishes, which sighted people see
        // from the spinner going away.
        .onChange(of: model.isScanning) { wasScanning, isScanning in
            if wasScanning && !isScanning { announce(itemCount.isEmpty ? "No videos found" : itemCount) }
        }
        .onChange(of: model.isRenaming) { wasRenaming, isRenaming in
            if wasRenaming && !isRenaming { announce(filingSummary) }
        }
        // The menu bar's commands (see Commands.swift), offered only while no
        // sheet is open.
        .focusedSceneValue(
            \.listCommands,
            searchingFor == nil
                ? ListCommands(
                    model: model, selection: selection, fileReady: fileReady,
                    searchAgain: searchAgain)
                : nil)
        // Forget selected rows once they're gone from the list.
        .onChange(of: model.items.count) {
            selection.formIntersection(model.items.map(\.id))
        }
        .dropDestination(for: URL.self) { urls, _ in
            model.add(urls)
            return true
        }
        .fileImporter(
            isPresented: $model.isImporting, allowedContentTypes: [.folder, .item],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result { model.add(urls) }
        }
        .alert(
            "Search The Movie Database",
            isPresented: Binding(get: { searchingFor != nil }, set: { if !$0 { searchingFor = nil } })
        ) {
            TextField("Title", text: $searchTitle)
            Button("Search") {
                if let id = searchingFor { model.search(searchTitle, for: id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Type the movie or show's name as it's usually written.")
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button("Add Files", systemImage: "plus") { model.isImporting = true }
                .help("Add movies, episodes or download folders. You can also drag them into this window.")
        }
        ToolbarItemGroup(placement: .primaryAction) {
            if model.isScanning {
                ProgressView()
                    .controlSize(.small)
                    .help("Finding videos in what you added")
                    .accessibilityLabel("Finding videos")
                Button("Stop") { model.stopScanning() }
                    .help("Stop searching the folders you added. Nothing found so far is added.")
            }
            if !model.items.isEmpty {
                // Empties the list (never touches any files). Not while
                // copying, which still needs the items' file access.
                Button("Clear") { model.clear() }
                    .disabled(model.isRenaming)
                    .help("Remove everything from this list. Your files aren't changed.")
            }
            Button(action: fileReady) {
                if model.isRenaming {
                    ProgressView().controlSize(.small)
                        .accessibilityLabel(model.mode == .copy ? "Copying" : "Moving")
                } else {
                    Text(primaryActionTitle)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.readyCount == 0 || model.isRenaming)
            .help(
                model.mode == .copy
                    ? "Copy matched files into your library" : "Move matched files into your library")
        }
    }

    /// Files the matched items. The first time, it asks for any library
    /// folder they need with the standard open panel, rather than failing
    /// with a message pointing to Settings. Cancelling the panel leaves
    /// those items with that message instead.
    private func fileReady() {
        Task {
            for kind in model.missingFolders {
                let window = NSApp.keyWindow
                guard let url = await LibraryFolders.choose(kind, attachedTo: window) else { continue }
                try? model.setFolder(url, for: kind)
            }
            await model.renameReady(undoManager: undoManager)
        }
    }

    /// Opens the Search Again sheet for one item, filled in with its title.
    private func searchAgain(_ id: LibraryModel.Item.ID) {
        searchTitle = model.items.first(where: { $0.id == id })?.parsed.title ?? ""
        searchingFor = id
    }

    /// "1,234 items" under the window title, so a long list's size is clear.
    private var itemCount: String {
        let count = model.items.count
        guard count > 0 else { return "" }
        return count == 1 ? "1 item" : "\(count.formatted()) items"
    }

    /// What VoiceOver says when a Copy or Move to Library finishes.
    private var filingSummary: String {
        let done = model.items.count(where: { $0.status == .done })
        let attention = model.items.count(where: { $0.statusRank == 0 })
        return attention == 0
            ? "\(done) in your library" : "\(done) in your library, \(attention) need attention"
    }

    private func announce(_ text: String) {
        AccessibilityNotification.Announcement(text).post()
    }

    /// Says what will happen, like Finder's Copy and Move: "Copy 3 to Library".
    private var primaryActionTitle: String {
        let verb = model.mode == .copy ? "Copy" : "Move"
        return model.readyCount > 0 ? "\(verb) \(model.readyCount) to Library" : "\(verb) to Library"
    }
}

// MARK: - Empty window

// The views below are handed the model directly instead of reading it from
// the environment. Table rows being removed (Delete key, Clear) are laid out
// once more after they've left the environment, and reading it then crashed
// the app.

private struct EmptyState: View {
    let model: LibraryModel

    var body: some View {
        ContentUnavailableView {
            Label("Drag Movies and TV Episodes Here", systemImage: "film.stack")
        } description: {
            Text(
                "Drag video files or whole download folders into this window, or click Add Files. "
                    + "Reelmark finds each title on The Movie Database "
                    + "and names it the way Jellyfin expects.")
        } actions: {
            Button("Add Files…") { model.isImporting = true }
        }
    }
}
