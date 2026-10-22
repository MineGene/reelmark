import Foundation
import Observation
import ReelmarkCore

/// The window's state: the files waiting to be filed, their matches, and
/// the user's settings. Everything here runs on the main thread except the
/// network lookups and the file moves, which are awaited.
///
/// Memory: only names, numbers and short text are kept (no artwork, no file
/// contents), and lookups run one at a time, so even hundreds of files use
/// very little.
@MainActor
@Observable
final class LibraryModel {

    struct Item: Identifiable {
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
            match.map { JellyfinNaming.relativePath(for: parsed, match: $0, fileExtension: source.pathExtension) }
        }
    }

    private(set) var items: [Item] = []
    private(set) var isRenaming = false
    var isImporting = false

    private(set) var token: String? = Keychain.readToken()
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

    // MARK: - Adding and removing

    func add(_ urls: [URL]) {
        for url in urls where !accessGranted.contains(url) {
            // Files chosen in the open panel need this; dropped files already
            // have access and simply return false.
            if url.startAccessingSecurityScopedResource() { accessGranted.append(url) }
        }
        let known = Set(items.map(\.source))
        for file in MediaFiles.videos(in: urls) where !known.contains(file) {
            let parsed = ReleaseNameParser.parse(
                fileName: file.lastPathComponent,
                parentFolder: file.deletingLastPathComponent().lastPathComponent)
            items.append(Item(source: file, parsed: parsed))
        }
        lookUpPending()
    }

    func remove(_ ids: Set<Item.ID>) {
        items.removeAll { ids.contains($0.id) }
        if items.isEmpty { clear() }
    }

    func clear() {
        lookup?.cancel()
        lookup = nil
        items = []
        cache = [:]
        for url in accessGranted { url.stopAccessingSecurityScopedResource() }
        accessGranted = []
    }

    func clearDone() {
        remove(Set(items.filter { $0.status == .done }.map(\.id)))
    }

    // MARK: - Matching

    func choose(_ matchID: Int, for id: Item.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].matchID = matchID
    }

    /// Searches again with a title the user typed.
    func search(_ title: String, for id: Item.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items[index].parsed.title = trimmed
        items[index].parsed.year = nil
        items[index].candidates = []
        items[index].matchID = nil
        items[index].status = .pending
        lookUpPending()
    }

    /// Looks up waiting items one at a time, gently on TMDB and on memory.
    private func lookUpPending() {
        guard lookup == nil, let token else { return }
        lookup = Task {
            // A cancelled lookup was already replaced; leave the new one be.
            defer { if !Task.isCancelled { lookup = nil } }
            let client = TMDBClient(token: token)
            while !Task.isCancelled, let index = items.firstIndex(where: { $0.status == .pending }) {
                let id = items[index].id
                let parsed = items[index].parsed
                items[index].status = .searching

                let key = "\(parsed.isEpisode)|\(parsed.title.lowercased())|\(parsed.year ?? 0)"
                let status: Item.Status
                var matches: [Match] = []
                do {
                    if let cached = cache[key] {
                        matches = cached
                    } else {
                        matches = try await client.search(parsed)
                        cache[key] = matches
                    }
                    status = matches.isEmpty ? .noMatch : .ready
                } catch {
                    status = .failed(Self.describe(error))
                }

                // The item may have been removed while we waited.
                guard let current = items.firstIndex(where: { $0.id == id }) else { continue }
                // Stopped (token removed): leave it waiting rather than failed.
                if Task.isCancelled {
                    items[current].status = .pending
                    break
                }
                items[current].candidates = matches
                items[current].matchID = matches.first?.id
                items[current].status = status

                // A bad token fails every search; stop until it's fixed.
                if Self.isAuthError(status) { break }
            }
        }
    }

    // MARK: - Filing

    /// Moves or copies every matched file into its library folder.
    func renameReady() async {
        guard !isRenaming else { return }
        isRenaming = true
        defer { isRenaming = false }
        let mode = self.mode

        for id in items.filter({ $0.status == .ready }).map(\.id) {
            guard let index = items.firstIndex(where: { $0.id == id }),
                let match = items[index].match, let path = items[index].newPath
            else { continue }

            guard let library = match.kind == .movie ? moviesFolder : showsFolder else {
                let name = match.kind == .movie ? "Movies" : "Shows"
                items[index].status = .failed("Choose a \(name) folder in Settings.")
                continue
            }

            let source = items[index].source
            let destination = library.appending(path: path)
            let hasAccess = library.startAccessingSecurityScopedResource()
            // Off the main thread: a copy to another drive can take minutes.
            let failure = await Task.detached { () -> String? in
                do {
                    try MediaFiles.transfer(source, to: destination, mode: mode)
                    return nil
                } catch {
                    return error.localizedDescription
                }
            }.value
            if hasAccess { library.stopAccessingSecurityScopedResource() }

            if let current = items.firstIndex(where: { $0.id == id }) {
                items[current].status = failure.map { Item.Status.failed($0) } ?? .done
            }
        }
    }

    // MARK: - Settings

    /// Checks the token with TMDB before saving it to the Keychain.
    func saveToken(_ newToken: String) async throws {
        let trimmed = newToken.trimmingCharacters(in: .whitespacesAndNewlines)
        try await TMDBClient(token: trimmed).validateToken()
        guard Keychain.saveToken(trimmed) else { throw KeychainError() }
        token = trimmed
        // Retry anything that failed for want of a working token.
        for index in items.indices where Self.isAuthError(items[index].status) {
            items[index].status = .pending
        }
        lookUpPending()
    }

    func removeToken() {
        lookup?.cancel()
        lookup = nil
        // Anything mid-search goes back to waiting for a token.
        for index in items.indices where items[index].status == .searching {
            items[index].status = .pending
        }
        Keychain.deleteToken()
        token = nil
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

    private static let authMessage = "TMDB didn't accept your access token. Check it in Settings."

    private static func isAuthError(_ status: Item.Status) -> Bool {
        status == .failed(authMessage)
    }

    static func describe(_ error: Error) -> String {
        switch error {
        case TMDBClient.Failure.invalidToken: authMessage
        case TMDBClient.Failure.http(429): "TMDB is busy. Try again in a moment."
        case TMDBClient.Failure.http(let code): "TMDB returned an error (\(code))."
        case let error as URLError where error.code == .notConnectedToInternet: "You're offline."
        default: error.localizedDescription
        }
    }
}
