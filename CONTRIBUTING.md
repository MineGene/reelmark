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

Reelmark has one maintainer, who sets its direction, tests on a real Mac and approves releases. Most code is written by Claude through Claude Code, openly; its commits, pull requests and comments come from [MachineGene](https://github.com/MachineGene), the maintainer's bot account for AI-written work. Decisions and their reasons are written down in issues and pull requests, so anyone can follow them. The maintainer aims to reply to new issues and pull requests within a week.

## Privacy rules

- **Never commit, attach or paste personal files**, real download names from your own library, or your own TMDB token. (The built-in token in `Reelmark/TMDBKey.swift` is Reelmark's and public on purpose.) Tests use invented release names and empty placeholder files.
- **Commit with your GitHub no-reply email.** Turn on *Keep my email addresses private* at [github.com/settings/emails](https://github.com/settings/emails), then `git config user.email "<id>+<username>@users.noreply.github.com"`.
- **Say when AI wrote it.** Much of Reelmark is written by Claude through Claude Code, and that's stated openly. If an AI tool wrote or substantially shaped your change, say so in the pull request and add a `Co-authored-by:` line for it.
- Commit trailers are limited to `Signed-off-by`, `Co-authored-by`, `Fixes`, `Closes`, `Resolves`, `Refs` and `Claude-Session`. Any email in them must be a GitHub no-reply address or `noreply@anthropic.com`.

The *Commit privacy* check enforces the email and trailer rules on every pull request.

## Workflow

1. Branch from `main`; one change per pull request.
2. Write commit messages the way Git itself asks: a short subject in the imperative ("Fix crash when clearing the list"), a blank line, then what the problem was and why this fixes it. Fill in the pull request template's sections. The history should make sense to someone who reads it years later.
3. Push and open a pull request. CI builds the app, runs the tests, checks permissions, web addresses and commit privacy, and runs CodeQL. Nothing needs a Mac except trying the app. A pull request that changes nothing the app or its tests use (docs, the changelog, other scripts and workflows) skips the macOS jobs, which then show as passed; `scripts/ci-changes.sh` lists what counts.
4. Pull requests from the maintainer and from MachineGene (Claude's) are squash-merged automatically once every required check passes: auto-merge is turned on as each one is opened. Pull requests from forks and Dependabot are merged by hand. The maintainer can still review, hold (turn off auto-merge) or close any pull request.

`main` is protected: no direct pushes, force pushes or deletions.

## Building locally (optional)

Requires Apple silicon and the Xcode version in `.xcode-version`.

```sh
scripts/build-app.sh                 # builds build/Release/Reelmark.app
scripts/check-app.sh build/Release/Reelmark.app
swift test --package-path Packages/ReelmarkCore
```

## Trying the app by hand

`scripts/make-test-downloads.sh` makes a folder of empty files named like downloads: free-to-show films for screenshots, and made-up names that try to break things (thousands of episodes, odd names, files that must be skipped, link loops). Reelmark only reads file names, so empty files behave exactly like real ones. `--count 100000` makes a data hoarder's folder, spread over up to 500 made-up shows so it still needs only a few hundred TMDB searches. Run it with `--help` for options.

## Rules the code must keep

See the "Rules the design depends on" section of `CLAUDE.md`: what may be sent and where, the fixed entitlements, never overwriting or deleting, the built-in token and the Keychain for a person's own, a tiny memory footprint, Apple's standard controls, and no third-party code.

## From idea to release

Reelmark follows established, public practices at each stage, so the process can be checked rather than taken on trust:

1. **Design.** Every change starts as an issue: a bug report, a feature request, or a short proposal for anything larger, saying the problem and the intended approach before code is written. Ideas are weighed against "What Reelmark is, and isn't" above and Apple's [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/).
2. **Code.** [GitHub flow](https://docs.github.com/en/get-started/using-github/github-flow): a short-lived branch from `main`, one change per pull request, with tests, a changelog entry and the README and other docs updated in the same pull request. Commit messages follow [Git's own guidelines](https://git-scm.com/docs/SubmittingPatches).
3. **Review and build.** Every pull request is built and tested by GitHub Actions (core tests, UI tests, the app checks, CodeQL, a reproducibility check, commit privacy and a workflow security audit) and reviewed by CodeRabbit (settings in `.coderabbit.yaml`). `main` only accepts pull requests whose required checks pass.
4. **Release.** Merging a change to the app publishes the next version straight away as a **pre-release**, built only by GitHub Actions, reproducibly, with a signed build record ([release engineering](https://sre.google/sre-book/release-engineering/) in Google's sense: automated, hermetic and repeatable). Version numbers follow [Semantic Versioning](https://semver.org), and [CHANGELOG.md](CHANGELOG.md) follows [Keep a Changelog](https://keepachangelog.com).
5. **Test on a Mac.** Checks that only a person on a real Mac can do (a real drag from Finder, chosen library folders, how something looks or sounds) are listed as checkboxes in each pull request's "Check on a Mac" section, each saying why it can't be automated. Anything a test can check is a test instead. The release collects them into a "Check <version> on a Mac" issue. A failed check becomes its own bug report.
6. **Promote.** Every Monday morning (Queensland time), the *Promote release* workflow makes the newest checked pre-release the stable release: one whose checklist issue is closed, along with those of every pre-release before it. The build isn't changed, only its label. An urgent fix can be promoted at once: **Actions › Promote release › Run workflow** with its version.
7. **Respond.** Security problems are reported privately (see [SECURITY.md](SECURITY.md)) and fixed in the latest release.

What changed in each version is recorded in [CHANGELOG.md](CHANGELOG.md). If your change affects what people see or can do, don't edit CHANGELOG.md: add a small file to [changelog.d](changelog.d) named after your branch, as its README describes. Separate files keep open pull requests from conflicting with each other. The release notes list the new entries, and they move into CHANGELOG.md in the first pull request after the release (`scripts/changelog.sh collect`).

Changes to docs, tests or CI alone don't make a release. A nightly run also checks `main`, in case a merge didn't start one. For a bigger version number (for example `0.2.0`): **Actions › Release › Run workflow**, keep the branch on `main`, and enter the version.
