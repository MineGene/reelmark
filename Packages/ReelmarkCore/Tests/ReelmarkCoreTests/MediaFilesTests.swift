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
}
