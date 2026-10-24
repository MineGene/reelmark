import XCTest

@testable import ReelmarkCore

/// Uses empty placeholder files in a temporary folder; never real media.
final class MediaFilesTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "ReelmarkTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private func make(_ path: String, contents: String = "") throws -> URL {
        let url = root.appending(path: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
        return url
    }

    func testFindsVideosInFoldersAndSkipsTheRest() throws {
        try make("Show.S01/Show.S01E02.mkv")
        try make("Show.S01/Show.S01E01.mkv")
        try make("Show.S01/Show.S01E01.nfo")
        try make("Show.S01/Sample/Show.S01E01.mkv")
        try make("Show.S01/show.s01e01.sample.mkv")
        try make("Show.S01/.hidden.mkv")
        let movie = try make("Movie.2020.MP4")

        let found = MediaFiles.videos(in: [root.appending(path: "Show.S01"), movie])
        XCTAssertEqual(
            found.map(\.lastPathComponent), ["Movie.2020.MP4", "Show.S01E01.mkv", "Show.S01E02.mkv"])
    }

    func testFindsEveryVideoTypeJellyfinPlays() throws {
        for name in ["a.avi", "b.MTS", "c.vob", "d.flv", "e.iso", "f.divx", "g.ts", "h.wmv"] {
            try make("Downloads/\(name)")
        }
        try make("Downloads/part.001")
        try make("Downloads/disc.bin")

        let found = MediaFiles.videos(in: [root.appending(path: "Downloads")])
        XCTAssertEqual(
            found.map(\.lastPathComponent),
            ["a.avi", "b.MTS", "c.vob", "d.flv", "e.iso", "f.divx", "g.ts", "h.wmv"])
    }

    func testSearchesEveryLevelOfAFolder() throws {
        try make("Pack/Show.S01/Disc 1/Extras/Show.S01E01.mkv")
        try make("Pack/Show.S02/Show.S02E01.mkv")
        try make("Pack/Movie.2020.mp4")

        let found = MediaFiles.videos(in: [root.appending(path: "Pack")])
        XCTAssertEqual(
            found.map(\.lastPathComponent), ["Movie.2020.mp4", "Show.S01E01.mkv", "Show.S02E01.mkv"])
    }

    func testFollowsLinkedFoldersWithoutLooping() throws {
        try make("Elsewhere/Movie.2021.mkv")
        try make("Drop/Movie.2020.mkv")
        let fm = FileManager.default
        try fm.createSymbolicLink(
            at: root.appending(path: "Drop/Linked"), withDestinationURL: root.appending(path: "Elsewhere"))
        // A link back to the dropped folder itself must not loop forever.
        try fm.createSymbolicLink(
            at: root.appending(path: "Drop/Loop"), withDestinationURL: root.appending(path: "Drop"))

        let found = MediaFiles.videos(in: [root.appending(path: "Drop")])
        XCTAssertEqual(found.map(\.lastPathComponent), ["Movie.2020.mkv", "Movie.2021.mkv"])
    }

    func testSampleInsideAWordIsKept() {
        XCTAssertTrue(MediaFiles.isVideo(URL(filePath: "/x/The.Sampler.2021.mkv")))
    }

    func testMoveCreatesFolders() throws {
        let source = try make("in/a.mkv", contents: "video")
        let destination = root.appending(path: "Library/Film (2020)/Film (2020).mkv")
        try MediaFiles.transfer(source, to: destination, mode: .move)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "video")
    }

    func testCopyKeepsOriginal() throws {
        let source = try make("in/b.mkv", contents: "video")
        let destination = root.appending(path: "Library/b.mkv")
        try MediaFiles.transfer(source, to: destination, mode: .copy)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
    }

    func testNeverOverwrites() throws {
        let source = try make("in/c.mkv", contents: "new")
        let destination = try make("Library/c.mkv", contents: "old")
        XCTAssertThrowsError(try MediaFiles.transfer(source, to: destination, mode: .move)) { error in
            XCTAssertEqual(error as? MediaFiles.TransferError, .alreadyExists("c.mkv"))
        }
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "old")
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    // MARK: Undo

    private func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }

    func testTransferReportsTheOutermostFolderItCreated() throws {
        try FileManager.default.createDirectory(
            at: root.appending(path: "Library"), withIntermediateDirectories: true)
        let source = try make("in/s.mkv")
        let created = try MediaFiles.transfer(
            source, to: root.appending(path: "Library/Show (2020)/Season 01/s.mkv"), mode: .copy)
        XCTAssertEqual(created?.lastPathComponent, "Show (2020)")

        let again = try make("in/t.mkv")
        XCTAssertNil(
            try MediaFiles.transfer(
                again, to: root.appending(path: "Library/Show (2020)/Season 01/t.mkv"), mode: .copy))
    }

    func testUndoMovePutsTheFileBack() throws {
        let source = try make("in/a.mkv", contents: "video")
        let destination = root.appending(path: "Library/Film (2020)/Film (2020).mkv")
        let created = try MediaFiles.transfer(source, to: destination, mode: .move)
        try MediaFiles.undoTransfer(source, to: destination, mode: .move, createdFolder: created)
        XCTAssertEqual(try String(contentsOf: source, encoding: .utf8), "video")
        XCTAssertFalse(exists(destination))
        XCTAssertFalse(exists(root.appending(path: "Library/Film (2020)")), "Empty folder left behind")
    }

    func testUndoCopyTrashesTheCopyAndKeepsTheOriginal() throws {
        let source = try make("in/b.mkv", contents: "video")
        let destination = root.appending(path: "Library/Film (2020)/Film (2020).mkv")
        let created = try MediaFiles.transfer(source, to: destination, mode: .copy)
        try MediaFiles.undoTransfer(source, to: destination, mode: .copy, createdFolder: created)
        XCTAssertEqual(try String(contentsOf: source, encoding: .utf8), "video")
        XCTAssertFalse(exists(destination))
        XCTAssertFalse(exists(root.appending(path: "Library/Film (2020)")))
    }

    func testUndoCopyKeepsTheCopyWhenTheOriginalIsGone() throws {
        let source = try make("in/c.mkv")
        let destination = root.appending(path: "Library/c.mkv")
        try MediaFiles.transfer(source, to: destination, mode: .copy)
        try FileManager.default.moveItem(at: source, to: root.appending(path: "elsewhere.mkv"))
        XCTAssertThrowsError(
            try MediaFiles.undoTransfer(source, to: destination, mode: .copy, createdFolder: nil)
        ) { error in
            XCTAssertEqual(error as? MediaFiles.TransferError, .originalMissing("c.mkv"))
        }
        XCTAssertTrue(exists(destination))
    }

    func testUndoMoveNeverOverwrites() throws {
        let source = try make("in/d.mkv", contents: "moved")
        let destination = root.appending(path: "Library/d.mkv")
        try MediaFiles.transfer(source, to: destination, mode: .move)
        try make("in/d.mkv", contents: "new download")
        XCTAssertThrowsError(
            try MediaFiles.undoTransfer(source, to: destination, mode: .move, createdFolder: nil)
        ) { error in
            XCTAssertEqual(error as? MediaFiles.TransferError, .originalPlaceTaken("d.mkv"))
        }
        XCTAssertEqual(try String(contentsOf: source, encoding: .utf8), "new download")
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "moved")
    }

    func testUndoKeepsAFolderThatHoldsOtherFiles() throws {
        let source = try make("in/e.mkv")
        let destination = root.appending(path: "Library/Film (2020)/Film (2020).mkv")
        let created = try MediaFiles.transfer(source, to: destination, mode: .copy)
        try make("Library/Film (2020)/Film (2020).en.srt")
        try MediaFiles.undoTransfer(source, to: destination, mode: .copy, createdFolder: created)
        XCTAssertTrue(exists(root.appending(path: "Library/Film (2020)/Film (2020).en.srt")))
    }

    func testUndoSaysWhenTheFileIsNoLongerInTheLibrary() throws {
        let source = try make("in/f.mkv")
        let destination = root.appending(path: "Library/f.mkv")
        try MediaFiles.transfer(source, to: destination, mode: .copy)
        try FileManager.default.moveItem(at: destination, to: root.appending(path: "renamed.mkv"))
        XCTAssertThrowsError(
            try MediaFiles.undoTransfer(source, to: destination, mode: .copy, createdFolder: nil)
        ) { error in
            XCTAssertEqual(error as? MediaFiles.TransferError, .notInLibrary("f.mkv"))
        }
    }
}
