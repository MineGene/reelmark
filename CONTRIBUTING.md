# Contributing

Thanks for helping. Reelmark handles people's media libraries and sends data to an online service, so privacy and safety come first.

## Privacy rules

- **Never commit, attach or paste personal files**, real download names from your own library, or your TMDB token. Tests use invented release names and empty placeholder files.
- **Commit with your GitHub no-reply email.** Turn on *Keep my email addresses private* at [github.com/settings/emails](https://github.com/settings/emails), then `git config user.email "<id>+<username>@users.noreply.github.com"`.
- **Say when AI wrote it.** Much of Reelmark is written by Claude through Claude Code, and that's stated openly. If an AI tool wrote or substantially shaped your change, say so in the pull request and add a `Co-authored-by:` line for it.
- Commit trailers are limited to `Signed-off-by`, `Co-authored-by`, `Fixes`, `Closes`, `Resolves`, `Refs` and `Claude-Session`. Any email in them must be a GitHub no-reply address or `noreply@anthropic.com`.

The *Commit privacy* check enforces the email and trailer rules on every pull request.

## Workflow

1. Branch from `main`; one change per pull request.
2. Push and open a pull request. CI builds the app, runs the tests, checks permissions, web addresses and commit privacy, and runs CodeQL. Nothing needs a Mac except trying the app.
3. The maintainer's pull requests (including Claude's) are squash-merged automatically once every required check passes: the *Auto-merge* workflow turns it on when they're opened. Pull requests from forks and Dependabot are merged by hand. The maintainer can still review, hold (turn off auto-merge) or close any pull request.
4. **Sensitive files need the maintainer's review.** Changes to permissions (`Config/`), workflows and scripts (`.github/`, `scripts/`), the Xcode project, the network code (`TMDBClient.swift`), Keychain use (`Keychain.swift`), the pinned Xcode version or `CLAUDE.md` wait until the maintainer adds the `maintainer-reviewed` label. A new push removes the label, so the reviewed version is the one that merges.

`main` is protected: no direct pushes, force pushes or deletions.

## Building locally (optional)

Requires Apple silicon and the Xcode version in `.xcode-version`.

```sh
scripts/build-app.sh                 # builds build/Release/Reelmark.app
scripts/check-app.sh build/Release/Reelmark.app
swift test --package-path Packages/ReelmarkCore
```

## Rules the code must keep

See the "Rules the design depends on" section of `CLAUDE.md`: what may be sent and where, the fixed entitlements, never overwriting or deleting, the Keychain for the token, a tiny memory footprint, Apple's standard controls, and no third-party code.

## Releases

Releases are automatic. Every night the *Release* workflow checks `main`; if the app has changed since the last release, it tests, builds and publishes the next patch version (0.1.1, 0.1.2, …) as a DMG with its checksum and build attestation, then verifies the download and rebuilds it from source on a fresh machine. Changes to docs, tests or CI alone don't make a release.

For a bigger version number (for example `0.2.0`) or to release straight away: **Actions › Release › Run workflow**, keep the branch on `main`, and optionally enter the version.
