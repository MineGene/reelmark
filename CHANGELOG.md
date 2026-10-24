# Changelog

All notable changes to Reelmark are listed here, newest first. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and Reelmark uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Each release's download, checksum and verification details are on the [Releases](https://github.com/MineGene/reelmark/releases) page.

## [Unreleased]

## [0.1.16] - 2026-10-24

### Added

- **Help › Report a Bug…** and **Request a Feature…** show what would be shared, then open a pre-filled GitHub issue in your browser. Nothing is sent unless you submit it, and file names, folders and tokens are never included.

### Changed

- Matching a long list of different titles is about four times faster: up to four lookups run at once, files with the same title share one lookup, and when The Movie Database is busy Reelmark waits as long as it asks.

### Fixed

- The window can be made much smaller, so macOS window tiling can fit it in half or a quarter of the screen beside other apps.

## [0.1.15] - 2026-10-24

### Added

- Videos and download folders can be dropped on Reelmark's Dock icon, opened with Finder's **Open With › Reelmark**, or added with Finder's **Services › Add to Reelmark**. Right-clicking the Dock icon offers **Add Files…**.

## [0.1.14] - 2026-10-24

### Changed

- The first time you copy or move files, Reelmark asks for your Jellyfin Movies or Shows folder instead of stopping with a message about Settings.

## [0.1.13] - 2026-10-24

### Added

- Two actions for the Shortcuts app and Spotlight: **Add Files to Reelmark**, and **Add Matched Files to Library**, which waits for the matches and then files them.

## [0.1.12] - 2026-10-24

### Added

- Apple's privacy manifest, which states that Reelmark doesn't track you and collects no data.

## [0.1.11] - 2026-10-24

### Added

- The File menu lists the window's commands with standard shortcuts: Copy (or Move) to Library (⌘Return), Search Again… (⌘R), Show in Finder (⇧⌘R), Remove from List (⌘Delete), Clear List (⌥⌘Delete) and Stop Adding Files (⌘.).

## [0.1.10] - 2026-10-24

### Added

- **Edit › Undo** (⌘Z) reverses the last Copy or Move to Library, as in Finder: moved files go back, and copies go to the Trash. **Edit › Redo** (⇧⌘Z) files them again.

## [0.1.9] - 2026-10-24

### Fixed

- Files can be dropped anywhere in the window, on the empty window and on a list of files, not just in its middle.

## [0.1.8] - 2026-10-23

### Changed

- The list is drawn with AppKit's table, the one Finder uses, so a long list uses far less memory (about 155 MB before with 190 files).
- Dropped folders are searched in the background, with a spinner and a Stop button, and the window's subtitle shows how many items are listed.
- Lists of tens of thousands of files stay responsive while they're matched and filed.
- The window opens at a fixed size instead of growing to fit the list.

### Fixed

- When The Movie Database is busy, Reelmark waits and tries again (after 2, 4 and 8 seconds) instead of failing the item.

## [0.1.7] - 2026-10-23

### Added

- Click a column header to sort the list A to Z, and again for Z to A. The status column sorts items that need attention first.

### Removed

- The footnote about Transmission under the Copy/Move setting.

## [0.1.6] - 2026-10-23

### Added

- Hovering over the warning icon explains what's wrong and what to do. VoiceOver reads the same text.

## [0.1.5] - 2026-10-23

### Changed

- **Clear** empties the whole list, including items with no match or that failed. It never touches files, and it's unavailable while files are being copied or moved.

## [0.1.4] - 2026-10-23

### Added

- TV episodes inside season folders are recognised, such as `Show/Season 2/S02E03.mkv` and `Show/Season 2/Episode 03.mkv`.

## [0.1.3] - 2026-10-23

### Changed

- No change to how the app works. Every change is now also tested by automated tests that use the app's window.

## [0.1.2] - 2026-10-23

### Added

- Every video type Jellyfin plays is found in dragged folders, including `.mts`, `.vob`, `.iso`, `.flv`, `.divx`, `.m2v` and `.ogv`.
- Folders reached through links are searched too.
- The install steps offer a one-line Terminal command to open a new version for the first time.

### Fixed

- Releases can be verified on any Mac, whatever its macOS version.

## [0.1.1] - 2026-10-23

### Added

- An app icon, in Apple's Liquid Glass style.
- A built-in TMDB access token, so Reelmark works with no setup. Adding your own token in Settings is optional.
- Credits in the About window.

### Changed

- Clearer wording: **Copy to Library** (or **Move to Library**) and **Clear** buttons, and the empty window explains drag and drop.

### Fixed

- Pressing Delete or clicking Clear no longer quits the app.

## [0.1.0] - 2026-10-23

### Added

- First release: drag in downloaded movies and TV episodes, check the matches from The Movie Database, and copy or move them into a Jellyfin library with the folder and file names Jellyfin expects.

[Unreleased]: https://github.com/MineGene/reelmark/compare/v0.1.16...HEAD
[0.1.16]: https://github.com/MineGene/reelmark/compare/v0.1.15...v0.1.16
[0.1.15]: https://github.com/MineGene/reelmark/compare/v0.1.14...v0.1.15
[0.1.14]: https://github.com/MineGene/reelmark/compare/v0.1.13...v0.1.14
[0.1.13]: https://github.com/MineGene/reelmark/compare/v0.1.12...v0.1.13
[0.1.12]: https://github.com/MineGene/reelmark/compare/v0.1.11...v0.1.12
[0.1.11]: https://github.com/MineGene/reelmark/compare/v0.1.10...v0.1.11
[0.1.10]: https://github.com/MineGene/reelmark/compare/v0.1.9...v0.1.10
[0.1.9]: https://github.com/MineGene/reelmark/compare/v0.1.8...v0.1.9
[0.1.8]: https://github.com/MineGene/reelmark/compare/v0.1.7...v0.1.8
[0.1.7]: https://github.com/MineGene/reelmark/compare/v0.1.6...v0.1.7
[0.1.6]: https://github.com/MineGene/reelmark/compare/v0.1.5...v0.1.6
[0.1.5]: https://github.com/MineGene/reelmark/compare/v0.1.4...v0.1.5
[0.1.4]: https://github.com/MineGene/reelmark/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/MineGene/reelmark/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/MineGene/reelmark/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/MineGene/reelmark/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/MineGene/reelmark/releases/tag/v0.1.0
