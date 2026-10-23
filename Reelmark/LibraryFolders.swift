import Foundation
import ReelmarkCore

/// Remembers the Movies and Shows library folders the user chose.
///
/// Reelmark is sandboxed, so it may only write where the user has pointed
/// it. A security-scoped bookmark is the sandbox's way of remembering that
/// permission between launches; it is stored in Reelmark's own preferences.
enum LibraryFolders {

    static func url(for kind: Match.Kind) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key(kind)) else { return nil }
        var isStale = false
        guard
            let url = try? URL(
                resolvingBookmarkData: data, options: .withSecurityScope,
                relativeTo: nil, bookmarkDataIsStale: &isStale)
        else { return nil }

        // A folder that was moved or renamed still resolves, but its
        // bookmark should be refreshed.
        if isStale, url.startAccessingSecurityScopedResource() {
            try? remember(url, for: kind)
            url.stopAccessingSecurityScopedResource()
        }
        return url
    }

    /// `url` must come from an open panel, which grants the access.
    static func remember(_ url: URL, for kind: Match.Kind) throws {
        let data = try url.bookmarkData(
            options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(data, forKey: key(kind))
    }

    private static func key(_ kind: Match.Kind) -> String {
        "libraryFolder.\(kind.rawValue)"
    }
}
