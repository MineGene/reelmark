# Working on Reelmark

Reelmark is a native macOS app (Swift, SwiftUI) that renames downloaded movies and TV episodes into the folder and file names Jellyfin expects, using The Movie Database (TMDB) to identify them. Most code is written by Claude through Claude Code, openly; the maintainer sets direction, tests on a real Mac and approves releases. Read CONTRIBUTING.md first; these notes add what an AI session needs.

## Commits and pull requests

- Commit as the maintainer, with the no-reply address: `git config user.name MineGene` and `git config user.email 187925417+MineGene@users.noreply.github.com`.
- End each commit message with the standard `Co-Authored-By: Claude <noreply@anthropic.com>` attribution. Don't hide AI involvement anywhere.
- Turn off this environment's commit signing for the repo (`git config commit.gpgsign false`): its key isn't linked to the maintainer's account, so GitHub shows "Unverified". Squash-merge commits are signed by GitHub.
- Stage files by name (`git add path/to/file`). Never use `git add -A`, `git add .` or `git commit -a`, and switch branches only with a clean working tree (`git status --short` empty).
- Run `scripts/check-commits.sh origin/main HEAD` before pushing.
- One change per branch and pull request. Open the pull request yourself (not as a draft), then turn on squash auto-merge with `gh pr merge <number> --auto --squash`, so it merges by itself once every required check passes. Turn it on with `gh` as the maintainer, never from a workflow: GitHub doesn't start workflows from merges made by its own token, so CI on `main` and the release wouldn't run. Merged app changes are released straight away (see `.github/workflows/release.yml`), so keep `main` releasable. Required checks: Commit privacy, Core tests (xcode-27), Build and check app, Analyze Swift, Reproducible build.
- Never push to `main` or force-push it; it is protected.

## Building and testing

- There is no Xcode here. GitHub Actions is the compiler and test runner: push, then read the check annotations (`scripts/annotate-errors.sh` turns errors into annotations with file and line).
- Target: macOS 26 or later, Apple silicon only, built with the Xcode pinned in `.xcode-version` (27.x) on GitHub's `xcode-27` runner image. The minimum is 26, not 27, only so the CodeQL scan can run: it doesn't support Xcode 27 yet, so it builds with Xcode 26.6 on `macos-26`. Keep code compatible with macOS 26; guard anything newer with `if #available(macOS 27, *)`.
- Core logic lives in `Packages/ReelmarkCore` with XCTest tests. Add tests for every behaviour change. Tests use invented release names and empty placeholder files, never real media or the network.
- The Xcode project uses a synchronized folder: new Swift files in `Reelmark/` need no project edit.
- Builds must stay reproducible: the *Reproducible build* check builds twice at different paths and compares `scripts/app-digest.sh` output. Never add timestamps, absolute paths or run-specific values to the build.

## Rules the design depends on

- **Privacy:** only a cleaned-up title and year (plus a TMDB access token) are sent, and only to `api.themoviedb.org`, over HTTPS, with an ephemeral session (no cache, cookies or credential storage). File names, paths and anything else about the user's files never leave the Mac and are never logged or written to disk. `scripts/check-app.sh` fails if any other web address appears in the app.
- **Permissions:** sandboxed with exactly four entitlements (sandbox, outgoing network, user-selected read-write, app-scoped bookmarks). `scripts/check-app.sh` enforces the list.
- **Never destroy data:** never overwrite an existing file; never delete anything. Moving is opt-in (Copy is the default).
- **Tokens:** Reelmark ships with its own read-only TMDB token (`TMDBKey.swift`). It is public on purpose: anything in an open-source app can be read out of it. A person's own token, if they add one in Settings, is used instead and lives only in the Keychain (`Keychain.swift`), never in preferences or files.
- **Memory:** the app runs on an 8 GB MacBook Neo alongside Jellyfin. Keep it tiny: no artwork or images, no file contents read, one lookup at a time, results cached only for the session, the app quits when its window closes.
- **Design:** standard SwiftUI and AppKit controls only, following Apple's Human Interface Guidelines, so the app picks up macOS's own look, light and dark mode and accessibility. No custom colours, fonts or chrome.
- **No third-party code** in the app or as a package dependency. No new build or test tool without a stated reason, a pinned version and a checksum.
- Keep code simple and commented where the why isn't obvious; the maintainer makes high-level decisions and doesn't read every line.
