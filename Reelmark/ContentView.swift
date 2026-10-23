import ReelmarkCore
import SwiftUI

/// The main window: drag files in, check the matches, press Copy to Library.
/// Standard SwiftUI controls only, so the window follows macOS's own design
/// (materials, toolbar, light and dark, accessibility) without custom styling.
struct ContentView: View {
    @Environment(LibraryModel.self) private var model
    @State private var selection = Set<LibraryModel.Item.ID>()
    @State private var searchingFor: LibraryModel.Item.ID?
    @State private var searchTitle = ""

    var body: some View {
        @Bindable var model = model
        Group {
            if model.items.isEmpty {
                EmptyState(model: model)
            } else {
                ItemTable(model: model, selection: $selection) { id in
                    searchTitle = model.items.first(where: { $0.id == id })?.parsed.title ?? ""
                    searchingFor = id
                }
            }
        }
        .toolbar { toolbar }
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
            if model.items.contains(where: { $0.status == .done }) {
                // A plain "Clear", as in Safari's Downloads list.
                Button("Clear") { model.clearDone() }
                    .help("Remove items that are already in your library from this list")
            }
            Button {
                Task { await model.renameReady() }
            } label: {
                if model.isRenaming {
                    ProgressView().controlSize(.small)
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

// MARK: - The list

private struct ItemTable: View {
    let model: LibraryModel
    @Binding var selection: Set<LibraryModel.Item.ID>
    let onSearch: (LibraryModel.Item.ID) -> Void

    var body: some View {
        Table(model.items, selection: $selection) {
            TableColumn("Downloaded File") { item in
                Text(item.source.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(item.source.lastPathComponent)
            }
            TableColumn("Match") { item in
                MatchCell(model: model, item: item)
            }
            TableColumn("New Name") { item in
                Text(item.newPath ?? "—")
                    .lineLimit(1)
                    .truncationMode(.head)
                    .foregroundStyle(item.newPath == nil ? Color.secondary : Color.primary)
                    .help(item.newPath ?? "")
            }
            TableColumn("") { item in
                StatusIcon(status: item.status)
            }
            .width(24)
        }
        .contextMenu(forSelectionType: LibraryModel.Item.ID.self) { ids in
            if ids.count == 1, let id = ids.first {
                Button("Search Again…") { onSearch(id) }
            }
            Button("Remove from List", role: .destructive) { model.remove(ids) }
        }
        .onDeleteCommand { model.remove(selection) }
    }
}

private struct MatchCell: View {
    let model: LibraryModel
    let item: LibraryModel.Item

    var body: some View {
        switch item.status {
        case .pending:
            Text("Waiting…")
                .foregroundStyle(.secondary)
        case .searching:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Searching…").foregroundStyle(.secondary)
            }
        case .noMatch:
            Text("No match — right-click to search again")
                .foregroundStyle(.secondary)
        case .failed(let message):
            Text(message)
                .foregroundStyle(.secondary)
                .help(message)
        case .ready, .done:
            if item.candidates.count > 1 && item.status == .ready {
                Picker(
                    "Match",
                    selection: Binding(
                        get: { item.matchID ?? 0 },
                        set: { model.choose($0, for: item.id) })
                ) {
                    ForEach(item.candidates) { match in
                        Text(match.displayName).tag(match.id)
                    }
                }
                .labelsHidden()
                .help(item.match?.overview ?? "")
            } else {
                Text(item.match?.displayName ?? "—")
                    .help(item.match?.overview ?? "")
            }
        }
    }
}

private struct StatusIcon: View {
    let status: LibraryModel.Item.Status

    var body: some View {
        // The hover text says why the icon is there; VoiceOver reads the same.
        switch status {
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .help("In your library")
                .accessibilityLabel("In your library")
        case .noMatch:
            warning(
                "Not found on The Movie Database. Right-click and choose Search Again… "
                    + "to try a different title.")
        case .failed(let message):
            warning(message)
        default:
            EmptyView()
        }
    }

    private func warning(_ reason: String) -> some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.yellow)
            .help(reason)
            .accessibilityLabel("Needs attention")
            .accessibilityHint(reason)
    }
}
