# Contributing

Thanks for thinking about helping with Reelmark. Every bug report, idea and fix makes it better for everyone who keeps a Jellyfin library on a Mac.

Reelmark handles people's media libraries and sends data to an online service, so privacy and safety come first. Everyone taking part is expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Ways to help

- **Report a bug:** use the [bug report form](https://github.com/MineGene/reelmark/issues/new?template=bug.yml). For a file Reelmark matched wrongly, a made-up name in the same style is enough.
- **Suggest a feature:** use the [feature request form](https://github.com/MineGene/reelmark/issues/new?template=feature.yml), or talk an idea through first in [Discussions](https://github.com/MineGene/reelmark/discussions).
- **Try new releases** on your own Mac and say what you find. Different Macs, macOS versions and library layouts all help.
- **Improve the docs:** the README, this guide and the in-app text should be clear to someone who has never used a terminal.
- **Fix something:** issues labelled [good first issue](https://github.com/MineGene/reelmark/labels/good%20first%20issue) or [help wanted](https://github.com/MineGene/reelmark/labels/help%20wanted) are good places to start.

Questions go in [Discussions](https://github.com/MineGene/reelmark/discussions); see [SUPPORT.md](SUPPORT.md).

## What Reelmark is, and isn't

Reelmark does one job: it names movies and TV episodes the way Jellyfin expects and files them into a library, privately and without fuss. It aims to feel like a part of macOS.

So some ideas, however good, won't fit, and the maintainer will say so kindly and explain why:

- Anything that sends more than a title and year off the Mac, or talks to any service but TMDB.
- Downloading artwork, subtitles or metadata files, which Jellyfin already does.
- Other media servers' naming schemes, music, or books.
- Third-party code, custom-styled controls, or features that keep Reelmark running in the background.

## Who decides

Reelmark has one maintainer, who sets its direction, tests on a real Mac and approves releases. Most code is written by Claude through Claude Code, openly. Decisions and their reasons are written down in issues and pull requests, so anyone can follow them. The maintainer aims to reply to new issues and pull requests within a week.

## Privacy rules

- **Never commit, attach or paste personal files**, real download names from your own library, or your own TMDB token. (The built-in token in `Reelmark/TMDBKey.swift` is Reelmark's and public on purpose.) Tests use invented release names and empty placeholder files.
- **Commit with your GitHub no-reply email.** Turn on *Keep my email addresses private* at [github.com/settings/emails](https://github.com/settings/emails), then `git config user.email "<id>+<username>@users.noreply.github.com"`.
- **Say when AI wrote it.** Much of Reelmark is written by Claude through Claude Code, and that's stated openly. If an AI tool wrote or substantially shaped your change, say so in the pull request and add a `Co-authored-by:` line for it.
- Commit trailers are limited to `Signed-off-by`, `Co-authored-by`, `Fixes`, `Closes`, `Resolves`, `Refs` and `Claude-Session`. Any email in them must be a GitHub no-reply address or `noreply@anthropic.com`.

The *Commit privacy* check enforces the email and trailer rules on every pull request.

## Workflow

1. Branch from `main`; one change per pull request.
2. Push and open a pull request. CI builds the app, runs the tests, checks permissions, web addresses and commit privacy, and runs CodeQL. Nothing needs a Mac except trying the app.
3. The maintainer's pull requests (including Claude's) are squash-merged automatically once every required check passes: auto-merge is turned on as each one is opened. Pull requests from forks and Dependabot are merged by hand. The maintainer can still review, hold (turn off auto-merge) or close any pull request.

`main` is protected: no direct pushes, force pushes or deletions.

## Building locally (optional)

Requires Apple silicon and the Xcode version in `.xcode-version`.

```sh
scripts/build-app.sh                 # builds build/Release/Reelmark.app
scripts/check-app.sh build/Release/Reelmark.app
swift test --package-path Packages/ReelmarkCore
```

## Trying the app by hand

`scripts/make-test-downloads.sh` makes a folder of empty files named like downloads: free-to-show films for screenshots, and made-up names that try to break things (thousands of episodes, odd names, files that must be skipped, link loops). Reelmark only reads file names, so empty files behave exactly like real ones. Run it with `--help` for options.

## Rules the code must keep

See the "Rules the design depends on" section of `CLAUDE.md`: what may be sent and where, the fixed entitlements, never overwriting or deleting, the built-in token and the Keychain for a person's own, a tiny memory footprint, Apple's standard controls, and no third-party code.

## Releases

What changed in each version is recorded in [CHANGELOG.md](CHANGELOG.md), in the [Keep a Changelog](https://keepachangelog.com) format. If your change affects what people see or can do, add a line under **Unreleased**.

Releases are automatic. As soon as a change to the app is merged into `main`, the *Release* workflow tests, builds and publishes the next patch version (0.1.1, 0.1.2, …) as a DMG with its checksum and build attestation, then verifies the download and rebuilds it from source on a fresh machine. Changes to docs, tests or CI alone don't make a release. A nightly run also checks `main`, in case a merge didn't start one.

For a bigger version number (for example `0.2.0`) or to release straight away: **Actions › Release › Run workflow**, keep the branch on `main`, and optionally enter the version.
