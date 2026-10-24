import Foundation

/// Finds video files among what the user dropped, and moves or copies them
/// into the library. Reads directory listings only; file contents are never
/// opened.
public enum MediaFiles {

    /// Every video type Jellyfin plays (its NamingOptions.VideoFileExtensions),
    /// except a few that are usually something else: split archives (.001),
    /// generic disc images (.bin, .img, .nrg) and DVD menu files (.ifo).
    public static let videoExtensions: Set<String> = [
        "3g2", "3gp", "amv", "asf", "asx", "avi", "bivx", "divx", "dv", "dvr-ms", "f4v", "fli",
        "flv", "iso", "m2t", "m2ts", "m2v", "m4v", "mk3d", "mkv", "mov", "mp4", "mpe", "mpeg",
        "mpg", "mts", "mxf", "nsv", "nuv", "ogm", "ogv", "pva", "qt", "rec", "rm", "rmvb",
        "strm", "svq3", "tp", "ts", "ty", "viv", "vob", "vp3", "webm", "wmv", "wtv", "xvid",
    ]

    /// Video files in the dropped items: files as they are, folders searched
    /// all the way down, including folders reached through links. Hidden
    /// files and "sample" clips are skipped.
    public static func videos(in urls: [URL]) -> [URL] {
        var found: [URL] = []
        var visited: Set<String> = []
        for url in urls { collect(url, into: &found, visited: &visited) }
        // Episodes in order, however the folders listed them. Paths are
        // resolved first: macOS can report one folder by two paths
        // (/var/… and /private/var/…), which would scramble the order, and
        // a file reached through two links is listed once.
        var seen: Set<String> = []
        let keyed = found.map { ($0, $0.resolvingSymlinksInPath().path) }
            .filter { seen.insert($0.1).inserted }
        return keyed.sorted { $0.1.localizedStandardCompare($1.1) == .orderedAscending }.map(\.0)
    }

    /// Adds the video at `url`, or every video inside it if it's a folder.
    /// Unlike FileManager's enumerator, this follows links to folders; each
    /// real folder is visited once, so a link back up the tree can't loop.
    /// A folder that can't be read is skipped and the rest are still searched.
    private static func collect(_ url: URL, into found: inout [URL], visited: inout Set<String>) {
        // Run from a task (as Reelmark does), searching stops when it's cancelled.
        if Task.isCancelled { return }
        let resolved = url.resolvingSymlinksInPath()
        let values = try? resolved.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        guard values?.isDirectory == true else {
            if isVideo(url) { found.append(url) }
            return
        }
        // Apps and other bundles aren't media folders.
        guard values?.isPackage != true, visited.insert(resolved.path).inserted else { return }
        // List the real folder: listing through a link's own path doesn't
        // follow the link.
        let children =
            (try? FileManager.default.contentsOfDirectory(
                at: resolved, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]))
            ?? []
        for child in children { collect(child, into: &found, visited: &visited) }
    }

    static func isVideo(_ url: URL) -> Bool {
        guard videoExtensions.contains(url.pathExtension.lowercased()) else { return false }
        let name = url.deletingPathExtension().lastPathComponent
        // Release "sample" clips: "Movie.2019.sample.mkv", "sample-movie.mkv",
        // or anything in a "Sample" folder.
        let isSample =
            name.firstMatch(of: /(?:^|[ ._-])sample(?:$|[ ._-])/.ignoresCase()) != nil
            || url.deletingLastPathComponent().lastPathComponent.lowercased() == "sample"
        return !isSample
    }

    // MARK: - Moving into the library

    public enum TransferMode: String, CaseIterable, Sendable {
        /// Moves the file. Instant on the same drive.
        case move
        /// Leaves the original in place, for example so a torrent client can
        /// keep seeding. Uses APFS clones where possible, so a copy on the
        /// same drive takes no extra space.
        case copy
    }

    public enum TransferError: LocalizedError, Equatable {
        case alreadyExists(String)
        case notInLibrary(String)
        case originalMissing(String)
        case originalPlaceTaken(String)

        public var errorDescription: String? {
            switch self {
            case .alreadyExists(let name): "“\(name)” is already in your library."
            case .notInLibrary(let name): "Couldn't undo: “\(name)” is no longer where Reelmark put it."
            case .originalMissing(let name):
                "Couldn't undo: the original of “\(name)” is gone, so the copy in your library was kept."
            case .originalPlaceTaken(let name):
                "Couldn't undo: something named “\(name)” is already where the file came from."
            }
        }
    }

    /// Moves or copies `source` to `destination`, creating folders as
    /// needed. Never overwrites: if the destination exists, nothing changes.
    /// Runs on whatever thread calls it; large copies can take a while.
    ///
    /// Returns the outermost folder it had to create, if any (for example
    /// "Film (2020)"), so an undo can tidy it away again.
    @discardableResult
    public static func transfer(_ source: URL, to destination: URL, mode: TransferMode) throws -> URL? {
        let manager = FileManager.default
        if manager.fileExists(atPath: destination.path) {
            throw TransferError.alreadyExists(destination.lastPathComponent)
        }
        var created: URL?
        var folder = destination.deletingLastPathComponent()
        while !manager.fileExists(atPath: folder.path), folder.pathComponents.count > 1 {
            created = folder
            folder = folder.deletingLastPathComponent()
        }
        try manager.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        switch mode {
        case .move: try manager.moveItem(at: source, to: destination)
        case .copy: try manager.copyItem(at: source, to: destination)
        }
        return created
    }

    /// Reverses `transfer`, the way Finder's Edit ▸ Undo does: a moved file
    /// goes back where it came from, and a copy goes to the Trash, where it
    /// can still be recovered. Nothing is ever deleted outright.
    ///
    /// A copy is only trashed while its original still exists, so undo can
    /// never leave the person with no copy at all. `createdFolder` (from
    /// `transfer`) also goes to the Trash, but only once it's empty.
    public static func undoTransfer(
        _ source: URL, to destination: URL, mode: TransferMode, createdFolder: URL?
    ) throws {
        let manager = FileManager.default
        let name = destination.lastPathComponent
        guard manager.fileExists(atPath: destination.path) else { throw TransferError.notInLibrary(name) }
        switch mode {
        case .move:
            if manager.fileExists(atPath: source.path) {
                throw TransferError.originalPlaceTaken(source.lastPathComponent)
            }
            try manager.moveItem(at: destination, to: source)
        case .copy:
            guard manager.fileExists(atPath: source.path) else { throw TransferError.originalMissing(name) }
            try manager.trashItem(at: destination, resultingItemURL: nil)
        }
        if let createdFolder { trashIfEmpty(createdFolder) }
    }

    /// Trashes `folder` if nothing but empty folders (like "Season 01") and
    /// Finder's hidden .DS_Store files is inside it. Anything else keeps it.
    private static func trashIfEmpty(_ folder: URL) {
        let manager = FileManager.default
        guard let contents = manager.enumerator(at: folder, includingPropertiesForKeys: [.isDirectoryKey])
        else { return }
        for case let url as URL in contents {
            let isFolder = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            if !isFolder && url.lastPathComponent != ".DS_Store" { return }
        }
        try? manager.trashItem(at: folder, resultingItemURL: nil)
    }
}
