import AppKit
import Foundation
import Observation
import ReelmarkCore

/// The window's state: the files waiting to be filed, their matches, and
/// the user's settings. Everything here runs on the main thread except the
/// network lookups and the file moves, which are awaited.
///
/// Memory: only names, numbers and short text are kept (no artwork, no file
/// contents), and at most four lookups run at once, so even thousands of files use
/// very little.
@MainActor
@Observable
final class LibraryModel {

    struct Item: Identifiable, Equatable {
        enum Status: Equatable {
            case pending  // not looked up yet
            case searching
            case ready  // has a match, waiting to be filed
            case noMatch
            case failed(String)
            case done
        }

        let id = UUID()
        let source: URL
        var parsed: ParsedName
        var candidates: [Match] = []
        var matchID: Int?
        var status: Status = .pending

        var match: Match? { candidates.first { $0.id == matchID } }

        /// Where the file will go, relative to the library folder.
        var newPath: String? {
            match.map {
                JellyfinNaming.relativePath(for: parsed, match: $0, fileExtension: source.pathExtension)
            }
        }

        // What each column of the list sorts by.
        var fileName: String { source.lastPathComponent }
        var matchName: String { match?.displayName ?? "" }
        var newName: String { newPath ?? "" }
        /// Items that need attention first, then waiting, then done.
        var statusRank: Int {
            switch status {
            case .noMatch, .failed: 0
            case .pending, .searching, .ready: 1
            case .done: 2
            }
        }
    }

    /// The one model the window, the menus and Shortcuts actions share.
    static let shared = LibraryModel.forLaunch()

    private(set) var items: [Item] = []
    /// How far the current Copy, Move, Undo or Redo has got, for the
    /// toolbar; nil when none is running.
    private(set) var filing: FilingProgress?
    var isRenaming: Bool { filing != nil }
    private let activity = FilingActivity()
    /// True while dropped folders are still being searched for videos.
    private(set) var isScanning = false
    var isImporting = false
    /// Which report Help › Report a Bug… or Request a Feature… is previewing.
    var report: IssueLink.Kind?

    /// The person's own TMDB token, if they've added one in Settings.
    private(set) var ownToken: String? = Keychain.readToken()
    /// The token searches use: their own if they added one, otherwise
    /// Reelmark's built-in one, so the app works with no setup.
    var token: String { ownToken ?? TMDBKey.builtIn }
    private(set) var moviesFolder: URL? = LibraryFolders.url(for: .movie)
    private(set) var showsFolder: URL? = LibraryFolders.url(for: .show)

    /// Copy by default: it never removes anything, and on the same drive an
    /// APFS copy takes no extra space.
    var mode: MediaFiles.TransferMode = LibraryModel.savedMode() {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "transferMode") }
    }

    private static func savedMode() -> MediaFiles.TransferMode {
        MediaFiles.TransferMode(rawValue: UserDefaults.standard.string(forKey: "transferMode") ?? "") ?? .copy
    }

    var readyCount: Int { items.count(where: { $0.status == .ready }) }

    /// Search results for this session only, so a season of 10 episodes
    /// costs one lookup, not ten. Never written to disk.
    @ObservationIgnored private var cache: [String: [Match]] = [:]
    /// Dropped or opened items the sandbox lets us use until the list is cleared.
    @ObservationIgnored private var accessGranted: [URL] = []
    @ObservationIgnored private var lookup: Task<Void, Never>?
    /// The window's undo history, which holds the last Copy or Move to Library.
    @ObservationIgnored private weak var undoManager: UndoManager?

    // Big drops (tens of thousands of files) stay quick: items are found by
    // ID through an index rather than by searching the list, and lookups
    // take the next waiting item from a queue.
    @ObservationIgnored private var positions: [Item.ID: Int] = [:]
    @ObservationIgnored private var waiting: [Item.ID] = []
    @ObservationIgnored private var nextWaiting = 0
    /// Folder searches still running; several drops can overlap.
    @ObservationIgnored private var scans: [UUID: Task<[Item], Never>] = [:]

    // MARK: - Adding and removing

    func add(_ urls: [URL]) {
        for url in urls where !accessGranted.contains(url) {
            // Files chosen in the open panel need this; dropped files already
            // have access and simply return false.
            if url.startAccessingSecurityScopedResource() { accessGranted.append(url) }
        }
        // Searching folders and reading names happens off the main thread,
        // so dropping thousands of files doesn't freeze the window.
        let known = Set(items.map(\.source))
        let key = UUID()
        let scan = Task.detached(priority: .userInitiated) { Self.newItems(in: urls, skipping: known) }
        scans[key] = scan
        isScanning = true
        Task {
            let found = await scan.value
            scans[key] = nil
            isScanning = !scans.isEmpty
            guard !scan.isCancelled else { return }
            // Another drop may have added some of the same files meanwhile.
            let present = Set(items.map(\.source))
            let fresh = found.filter { !present.contains($0.source) }
            items.append(contentsOf: fresh)
            reindex()
            waiting.append(contentsOf: fresh.map(\.id))
            lookUpPending()
        }
    }

    /// Waits until added folders are searched and every item is looked up,
    /// so a Shortcut can add files and file them in one go.
    func waitUntilMatched() async {
        while isScanning || lookup != nil {
            if Task.isCancelled { return }
            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    /// Stops searching dropped folders; nothing found so far is added.
    func stopScanning() {
        for scan in scans.values { scan.cancel() }
    }

    /// The videos in what was dropped, with their names read. Runs off the
    /// main thread and stops early if cancelled.
    nonisolated private static func newItems(in urls: [URL], skipping known: Set<URL>) -> [Item] {
        var found: [Item] = []
        for file in MediaFiles.videos(in: urls) where !known.contains(file) {
            if Task.isCancelled { return [] }
            let folder = file.deletingLastPathComponent()
            let parsed = ReleaseNameParser.parse(
                fileName: file.lastPathComponent,
                parentFolder: folder.lastPathComponent,
                grandparentFolder: folder.deletingLastPathComponent().lastPathComponent)
            found.append(Item(source: file, parsed: parsed))
        }
        return found
    }

    func remove(_ ids: Set<Item.ID>) {
        items.removeAll { ids.contains($0.id) }
        reindex()
        if items.isEmpty { clear() }
    }

    func clear() {
        lookup?.cancel()
        lookup = nil
        stopScanning()
        items = []
        reindex()
        waiting = []
        nextWaiting = 0
        cache = [:]
        for url in accessGranted { url.stopAccessingSecurityScopedResource() }
        accessGranted = []
        // Undo needs the files' access, just given up, to move them back.
        undoManager?.removeAllActions(withTarget: self)
    }

    /// Rebuilds the ID index after items are added or removed. (Changing an
    /// item in place doesn't move it, so needs no reindex.)
    private func reindex() {
        positions = Dictionary(uniqueKeysWithValues: items.indices.map { (items[$0].id, $0) })
    }

    private func index(of id: Item.ID) -> Int? {
        guard let index = positions[id], items.indices.contains(index), items[index].id == id else {
            return nil
        }
        return index
    }

    /// The next item waiting to be looked up, in the order they were added.
    private func nextToLookUp() -> Int? {
        while nextWaiting < waiting.count {
            let id = waiting[nextWaiting]
            nextWaiting += 1
            if let index = index(of: id), items[index].status == .pending { return index }
        }
        waiting = []
        nextWaiting = 0
        return nil
    }

    // MARK: - Matching

    func choose(_ matchID: Int, for id: Item.ID) {
        guard let index = index(of: id) else { return }
        items[index].matchID = matchID
    }

    /// Searches again with a title the user typed.
    func search(_ title: String, for id: Item.ID) {
        guard let index = index(of: id) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items[index].parsed.title = trimmed
        items[index].parsed.year = nil
        items[index].candidates = []
        items[index].matchID = nil
        items[index].status = .pending
        waiting.append(id)
        lookUpPending()
    }

    /// Looks up waiting items, a few at a time (parallelLookups), gently on TMDB and on memory.
    /// How many lookups run at once: fast enough for a big list of different
    /// titles, and at about 8 requests a second at most, far under the
    /// roughly 40 a second TMDB asks apps to stay below.
    static let parallelLookups = 4

    private func lookUpPending() {
        guard lookup == nil else { return }
        lookup = Task {
            // A cancelled lookup was already replaced; leave the new one be.
            defer { if !Task.isCancelled { lookup = nil } }
            let client = TMDBClient(token: token)
            lookupsBlocked = false
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<Self.parallelLookups {
                    group.addTask { await self.lookUpWorker(client) }
                }
            }
        }
    }

    /// Set when TMDB rejects the token, so every worker stops until it's fixed.
    @ObservationIgnored private var lookupsBlocked = false
    /// Searches already on their way, so workers that reach the same title
    /// (a season pack) share one request instead of each sending their own.
    @ObservationIgnored private var inFlight: [String: Task<[Match], Error>] = [:]

    /// One of the parallel lookups: takes the next waiting item until none
    /// are left. Workers run on the main thread between network calls, so
    /// they never touch the list at the same time.
    private func lookUpWorker(_ client: TMDBClient) async {
        var answeredFromCache = 0
        while !Task.isCancelled, !lookupsBlocked, let index = nextToLookUp() {
            let id = items[index].id
            let parsed = items[index].parsed
            items[index].status = .searching

            let key = "\(parsed.isEpisode)|\(parsed.title.lowercased())|\(parsed.year ?? 0)"
            let status: Item.Status
            var matches: [Match] = []
            do {
                if let cached = cache[key] {
                    matches = cached
                    // A long season pack is answered from the cache
                    // without waiting; let the window update now and then.
                    answeredFromCache += 1
                    if answeredFromCache.isMultiple(of: 200) { await Task.yield() }
                } else if let running = inFlight[key] {
                    matches = try await running.value
                } else {
                    let search = Task { try await Self.search(client, parsed) }
                    inFlight[key] = search
                    defer { inFlight[key] = nil }
                    matches = try await search.value
                    cache[key] = matches
                }
                status = matches.isEmpty ? .noMatch : .ready
            } catch {
                status = .failed(Self.describe(error))
            }

            // The item may have been removed while we waited.
            guard let current = self.index(of: id) else { continue }
            // Stopped (token changed): leave it waiting rather than failed.
            if Task.isCancelled {
                items[current].status = .pending
                break
            }
            items[current].candidates = matches
            items[current].matchID = matches.first?.id
            items[current].status = status

            // A bad token fails every search; stop until it's fixed.
            if Self.isAuthError(status) {
                lookupsBlocked = true
                break
            }
        }
    }

    /// TMDB answers "busy" (429) when asked too often in a short time. Wait
    /// as long as it asks (Retry-After), or else 2, 4 and then 8 seconds,
    /// and try again before giving up on the item.
    private static func search(_ client: TMDBClient, _ parsed: ParsedName) async throws -> [Match] {
        var wait = 2
        while true {
            do {
                return try await client.search(parsed)
            } catch TMDBClient.Failure.busy(let retryAfter) where wait <= 8 {
                try await Task.sleep(for: .seconds(max(retryAfter ?? 0, wait)))
                wait *= 2
            }
        }
    }

    // MARK: - Filing

    /// One file Reelmark put in the library, kept so Edit ▸ Undo can reverse it.
    struct Transfer: Sendable {
        let id: Item.ID
        let source: URL
        let destination: URL
        let library: URL
        let createdFolder: URL?
    }

    /// One Copy or Move to Library, which Edit ▸ Undo reverses and Edit ▸
    /// Redo repeats. A class, so a redo can record the folders it creates
    /// for the next undo.
    @MainActor
    final class Batch {
        let mode: MediaFiles.TransferMode
        var transfers: [Transfer]

        init(mode: MediaFiles.TransferMode, transfers: [Transfer]) {
            self.mode = mode
            self.transfers = transfers
        }

        var actionName: String { mode == .copy ? "Copy to Library" : "Move to Library" }
    }

    /// Moves or copies every matched file into its library folder. The whole
    /// batch can then be reversed with Edit ▸ Undo (Command-Z) and repeated
    /// with Edit ▸ Redo (Shift-Command-Z), as in Finder.
    func renameReady(undoManager: UndoManager?) async {
        let ready = items.filter({ $0.status == .ready }).map(\.id)
        guard !isRenaming, !ready.isEmpty else { return }
        beginFiling(ready.count)
        defer { endFiling() }
        let mode = self.mode
        var done: [Transfer] = []
        defer {
            if let undoManager, !done.isEmpty {
                self.undoManager = undoManager
                registerUndo(of: Batch(mode: mode, transfers: done))
            }
        }

        for id in ready {
            defer { stepFiling() }
            guard let index = index(of: id),
                let match = items[index].match, let path = items[index].newPath
            else { continue }

            guard let library = match.kind == .movie ? moviesFolder : showsFolder else {
                let name = match.kind == .movie ? "Movies" : "Shows"
                items[index].status = .failed("Choose a \(name) folder in Settings.")
                continue
            }

            let source = items[index].source
            let destination = library.appending(path: path)
            if let created = await transfer(id: id, source, to: destination, in: library, mode: mode) {
                done.append(
                    Transfer(
                        id: id, source: source, destination: destination, library: library,
                        createdFolder: created.createdFolder))
            }
        }
    }

    /// Moves or copies one file and updates its row. Returns nil if it
    /// failed, otherwise the outermost folder it created (if any).
    private func transfer(
        id: Item.ID, _ source: URL, to destination: URL, in library: URL, mode: MediaFiles.TransferMode
    ) async -> Filed? {
        let hasAccess = library.startAccessingSecurityScopedResource()
        // Off the main thread: a copy to another drive can take minutes.
        let result = await Task.detached { () -> Result<URL?, Error> in
            Result { try MediaFiles.transfer(source, to: destination, mode: mode) }
        }.value
        if hasAccess { library.stopAccessingSecurityScopedResource() }

        if let current = index(of: id) {
            switch result {
            case .success: items[current].status = .done
            case .failure(let error): items[current].status = .failed(error.localizedDescription)
            }
        }
        guard case .success(let created) = result else { return nil }
        return Filed(createdFolder: created)
    }

    private struct Filed {
        let createdFolder: URL?
    }

    struct FilingProgress: Equatable {
        var done: Int
        let total: Int
    }

    private func beginFiling(_ total: Int) {
        filing = FilingProgress(done: 0, total: total)
        activity.start(total: total)
    }

    private func stepFiling() {
        filing?.done += 1
        activity.update(done: filing?.done ?? 0)
    }

    private func endFiling() {
        filing = nil
        activity.finish()
    }

    // Undo and redo. Each handler registers its opposite straight away (that's
    // how UndoManager tells an undo from a redo), then does the file work in
    // a task, since moving files back from another drive can take a while.

    private func registerUndo(of batch: Batch) {
        undoManager?.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated { model.undo(batch) }
        }
        undoManager?.setActionName(batch.actionName)
    }

    private func undo(_ batch: Batch) {
        undoManager?.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated { model.redo(batch) }
        }
        undoManager?.setActionName(batch.actionName)
        Task { await reverse(batch) }
    }

    private func redo(_ batch: Batch) {
        registerUndo(of: batch)
        Task { await repeatTransfers(batch) }
    }

    /// Reverses a Copy or Move to Library, newest file first so folders
    /// Reelmark created are empty again by the time they're checked. Moved
    /// files go back where they were; copies go to the Trash. Items still in
    /// the list are ready to file again.
    private func reverse(_ batch: Batch) async {
        guard !isRenaming else { return }
        beginFiling(batch.transfers.count)
        defer { endFiling() }

        let mode = batch.mode
        for transfer in batch.transfers.reversed() {
            defer { stepFiling() }
            let hasAccess = transfer.library.startAccessingSecurityScopedResource()
            let result = await Task.detached { () -> Result<Void, Error> in
                Result {
                    try MediaFiles.undoTransfer(
                        transfer.source, to: transfer.destination, mode: mode,
                        createdFolder: transfer.createdFolder)
                }
            }.value
            if hasAccess { transfer.library.stopAccessingSecurityScopedResource() }

            if let current = index(of: transfer.id) {
                switch result {
                case .success: items[current].status = .ready
                case .failure(let error): items[current].status = .failed(error.localizedDescription)
                }
            }
        }
    }

    /// Files the same files again, to the same places. Only the ones that
    /// succeed are kept for the next undo.
    private func repeatTransfers(_ batch: Batch) async {
        guard !isRenaming else { return }
        beginFiling(batch.transfers.count)
        defer { endFiling() }

        var done: [Transfer] = []
        for old in batch.transfers {
            defer { stepFiling() }
            if let created = await transfer(
                id: old.id, old.source, to: old.destination, in: old.library, mode: batch.mode)
            {
                done.append(
                    Transfer(
                        id: old.id, source: old.source, destination: old.destination, library: old.library,
                        createdFolder: created.createdFolder))
            }
        }
        batch.transfers = done
    }

    /// The library folders that matched items are waiting for, Movies first.
    var missingFolders: [Match.Kind] {
        let kinds = Set(items.filter { $0.status == .ready }.compactMap { $0.match?.kind })
        return [Match.Kind.movie, .show].filter {
            kinds.contains($0) && ($0 == .movie ? moviesFolder : showsFolder) == nil
        }
    }

    /// Shows the items in Finder, selected: a file already in the library
    /// where it is now, anything else where it was downloaded.
    func showInFinder(_ ids: Set<Item.ID>) {
        let urls = items.filter { ids.contains($0.id) }.map { item in
            guard item.status == .done, let match = item.match, let path = item.newPath,
                let library = match.kind == .movie ? moviesFolder : showsFolder
            else { return item.source }
            return library.appending(path: path)
        }
        if !urls.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(urls) }
    }

    // MARK: - Settings

    /// Checks the person's own token with TMDB before saving it to the Keychain.
    func saveToken(_ newToken: String) async throws {
        let trimmed = newToken.trimmingCharacters(in: .whitespacesAndNewlines)
        try await TMDBClient(token: trimmed).validateToken()
        guard Keychain.saveToken(trimmed) else { throw KeychainError() }
        ownToken = trimmed
        restartLookups()
    }

    /// Goes back to Reelmark's built-in token.
    func removeToken() {
        Keychain.deleteToken()
        ownToken = nil
        restartLookups()
    }

    /// Searches again with the current token: anything mid-search or
    /// rejected for its token goes back to waiting.
    private func restartLookups() {
        lookup?.cancel()
        lookup = nil
        for index in items.indices
        where items[index].status == .searching || Self.isAuthError(items[index].status) {
            items[index].status = .pending
            waiting.append(items[index].id)
        }
        lookUpPending()
    }

    func setFolder(_ url: URL, for kind: Match.Kind) throws {
        try LibraryFolders.remember(url, for: kind)
        switch kind {
        case .movie: moviesFolder = url
        case .show: showsFolder = url
        }
    }

    // MARK: - Messages

    struct KeychainError: LocalizedError {
        var errorDescription: String? { "The token couldn't be saved to your Keychain." }
    }

    private static let authMessage = "TMDB didn't accept the access token. Check it in Settings."

    private static func isAuthError(_ status: Item.Status) -> Bool {
        status == .failed(authMessage)
    }

    static func describe(_ error: Error) -> String {
        switch error {
        case TMDBClient.Failure.invalidToken: authMessage
        case TMDBClient.Failure.busy: "TMDB is busy. Try again in a moment."
        case TMDBClient.Failure.http(let code): "TMDB returned an error (\(code))."
        case let error as URLError where error.code == .notConnectedToInternet: "You're offline."
        default: error.localizedDescription
        }
    }
}

#if DEBUG
    // MARK: - UI tests

    extension LibraryModel {
        /// The model the app starts with. Debug builds launched with
        /// "-ui-testing" (by the UI tests in ReelmarkUITests) start with
        /// made-up items instead of an empty list. Release builds don't
        /// contain this code at all.
        static func forLaunch() -> LibraryModel {
            let model = LibraryModel()
            if CommandLine.arguments.contains("-ui-testing") { model.loadUITestItems() }
            return model
        }

        /// One item ready to copy, two already in the library and one with no
        /// match. The files don't exist and nothing is looked up online.
        private func loadUITestItems() {
            func item(_ id: Int, _ name: String, _ title: String, _ status: Item.Status) -> Item {
                let match = Match(id: id, kind: .movie, title: title, year: 2020)
                let found = status == .noMatch ? [] : [match]
                return Item(
                    source: URL(filePath: "/ReelmarkUITests/\(name)"),
                    parsed: ParsedName(title: title, year: 2020, kind: .movie),
                    candidates: found, matchID: found.first?.id, status: status)
            }
            // The count comes from the environment, not the command line:
            // macOS treats a bare value like "300" after an app's arguments as
            // a file to open, and then the app's window never appeared.
            if let count = ProcessInfo.processInfo.environment["REELMARK_UI_TEST_ITEMS"].flatMap(Int.init) {
                // Added just after launch, as a real drop would be.
                Task {
                    items = (1...max(count, 1)).map(Self.uiTestEpisode)
                    reindex()
                }
                return
            }
            items = [
                item(1, "Ready.Movie.2020.mkv", "Ready Movie", .ready),
                item(2, "Copied.Movie.2020.mkv", "Copied Movie", .done),
                item(3, "Another.Copied.Movie.2020.mkv", "Another Copied Movie", .done),
                item(4, "Unknown.Thing.2020.mkv", "Unknown Thing", .noMatch),
            ]
            reindex()
        }

        /// For the large-list UI test (REELMARK_UI_TEST_ITEMS): a long season pack
        /// where every row offers three possible matches, the heaviest kind
        /// of row the list draws.
        private static func uiTestEpisode(_ number: Int) -> Item {
            let shows = (0..<3).map {
                Match(id: number * 10 + $0, kind: .show, title: "Made Up Show \($0 + 1)", year: 2020 + $0)
            }
            let episode = String(format: "S%02dE%02d", number / 100 + 1, number % 100)
            return Item(
                source: URL(filePath: "/ReelmarkUITests/Made.Up.Show.\(episode).mkv"),
                parsed: ParsedName(
                    title: "Made Up Show",
                    kind: .episode(season: number / 100 + 1, episodes: [number % 100])),
                candidates: shows, matchID: shows[0].id, status: .ready)
        }
    }
#else
    extension LibraryModel {
        static func forLaunch() -> LibraryModel { LibraryModel() }
    }
#endif
