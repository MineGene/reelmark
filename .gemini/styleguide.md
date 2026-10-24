# Reviewing Reelmark

Reelmark is a small, sandboxed macOS app (Swift, SwiftUI and AppKit) that renames downloaded movies and TV episodes for Jellyfin, using The Movie Database (TMDB). `CLAUDE.md` holds the full project rules; these are the ones a review should check.

## Rules the design depends on

- **Privacy:** only a cleaned-up title and year (plus a TMDB access token) may leave the Mac, only to `api.themoviedb.org`, over HTTPS, with an ephemeral URL session. File names, paths and anything else about the user's files must never be sent, logged or written to disk. Flag any new web address, logging of file names or paths, or persistence of them.
- **Permissions:** exactly four sandbox entitlements (sandbox, outgoing network, user-selected read-write, app-scoped bookmarks). Flag anything that needs more.
- **Never destroy data:** never overwrite an existing file and never delete anything. The one exception is Edit ▸ Undo, which sends copies Reelmark made to the Trash, only while the original still exists. Flag `removeItem`, overwriting writes, or moves that could replace a file.
- **Tokens:** the built-in TMDB token in `TMDBKey.swift` is public on purpose; a person's own token lives only in the Keychain. Flag a token stored anywhere else.
- **Memory:** the app must stay tiny: no artwork or images, no reading file contents, one network lookup at a time, results cached for the session only.
- **Design:** standard SwiftUI and AppKit controls only, following Apple's Human Interface Guidelines. No custom colours, fonts or chrome.
- **No third-party code** in the app or as a package dependency.
- **Compatibility:** must build for macOS 26 with Xcode 26.6 (the CodeQL build) as well as Xcode 27; anything newer needs `if #available(macOS 27, *)`.
- **Concurrency:** Swift 6 with strict concurrency. Watch for main-actor state touched from detached tasks, and non-Sendable values crossing actors.
- **Reproducible builds:** no timestamps, absolute paths or run-specific values in the build.

## Tests

- Behaviour changes in `Packages/ReelmarkCore` need XCTest tests using invented release names and empty placeholder files, never real media or the network.
- Window changes need a UI test in `ReelmarkUITests/`.

## Writing

Commit messages and pull request descriptions follow Git's SubmittingPatches and Google's "Writing good CL descriptions": imperative subjects, the problem and reasoning in the body, neutral voice. User-facing changes add an entry to `CHANGELOG.md` under Unreleased (Keep a Changelog).

Don't comment on formatting that swift-format checks, or ask for comments on obvious code.
