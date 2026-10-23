import Foundation

/// Finds video files among what the user dropped, and moves or copies them
/// into the library. Reads directory listings only; file contents are never
/// opened.
public enum MediaFiles {

    public static let videoExtensions: Set<String> = [
        "mkv", "mp4", "m4v", "avi", "mov", "wmv", "ts", "m2ts", "webm", "mpg", "mpeg",
    ]

    /// Video files in the dropped items: files as they are, folders searched
    /// all the way down. Hidden files and "sample" clips are skipped.
    public static func videos(in urls: [URL]) -> [URL] {
        var found: [URL] = []
        for url in urls {
            if isDirectory(url) {
                let files = FileManager.default.enumerator(
                    at: url, includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants])
                while let file = files?.nextObject() as? URL {
                    if isVideo(file) { found.append(file) }
                }
            } else if isVideo(url) {
                found.append(url)
            }
        }
        // Episodes in order, however the folders listed them. Paths are
        // resolved first: macOS can report one folder by two paths
        // (/var/… and /private/var/…), which would scramble the order.
        let keyed = found.map { ($0, $0.resolvingSymlinksInPath().path) }
        return keyed.sorted { $0.1.localizedStandardCompare($1.1) == .orderedAscending }.map(\.0)
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

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
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

        public var errorDescription: String? {
            switch self {
            case .alreadyExists(let name): "“\(name)” is already in your library."
            }
        }
    }

    /// Moves or copies `source` to `destination`, creating folders as
    /// needed. Never overwrites: if the destination exists, nothing changes.
    /// Runs on whatever thread calls it; large copies can take a while.
    public static func transfer(_ source: URL, to destination: URL, mode: TransferMode) throws {
        let manager = FileManager.default
        if manager.fileExists(atPath: destination.path) {
            throw TransferError.alreadyExists(destination.lastPathComponent)
        }
        try manager.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        switch mode {
        case .move: try manager.moveItem(at: source, to: destination)
        case .copy: try manager.copyItem(at: source, to: destination)
        }
    }
}
