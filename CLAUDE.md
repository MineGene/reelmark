# Working on Reelmark

Reelmark is a native macOS app (Swift, SwiftUI) that renames downloaded movies and TV episodes into the folder and file names Jellyfin expects, using The Movie Database (TMDB) to identify them. Most code is written by Claude through Claude Code, openly; the maintainer sets direction, tests on a real Mac and approves releases. Read CONTRIBUTING.md first; these notes add what an AI session needs.

## Commits and pull requests

- Commit as [MachineGene](https://github.com/MachineGene), the maintainer's bot account for work written by AI tools such as Claude, with its no-reply address: `git config user.name MachineGene` and `git config user.email 347314855+MachineGene@users.noreply.github.com`. Commits then show as the bot's, separate from the maintainer's own.
- Pull requests, comments and auto-merge still appear under the maintainer's name: a cloud session reaches GitHub through the maintainer's own connection, and a token added to the environment doesn't replace it. The attribution lines below mark them as Claude's.
- End each commit message with the standard `Co-Authored-By: Claude <noreply@anthropic.com>` attribution. Don't hide AI involvement anywhere.
- Turn off this environment's commit signing for the repo (`git config commit.gpgsign false`): its key isn't linked to the maintainer's account, so GitHub shows "Unverified". Squash-merge commits are signed by GitHub.
- Stage files by name (`git add path/to/file`). Never use `git add -A`, `git add .` or `git commit -a`, and switch branches only with a clean working tree (`git status --short` empty).
- Run `scripts/check-commits.sh origin/main HEAD` before pushing.
- One change per branch and pull request. Open the pull request yourself (not as a draft), then turn on squash auto-merge, so it merges by itself once every required check passes, and watch its CI through to the merge. Turn it on as the maintainer: `gh pr merge <number> --auto --squash`, or in a cloud session the GitHub connector's enable-auto-merge tool, which acts as the maintainer's account. Never turn it on from a workflow: GitHub doesn't start workflows from merges made by its own token, so CI on `main` and the release wouldn't run. Merged app changes are published straight away as a pre-release (see `.github/workflows/release.yml`), so keep `main` releasable; the weekly *Promote release* workflow makes a checked pre-release the stable one. CONTRIBUTING.md's "From idea to release" is the process, stage by stage. Required checks: Commit privacy, Core tests (xcode-27), Build and check app, UI tests, Analyze Swift, Reproducible build.
- After every change, check whether the README, CONTRIBUTING.md, SECURITY.md, SUPPORT.md or this file need updating to match, and update them in the same pull request.
- **Changelog:** `CHANGELOG.md` follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/). A pull request that changes what people see or can do adds its entry as a new file, `changelog.d/<branch>.md`, in the right group (Added, Changed, Deprecated, Removed, Fixed, Security), written for users rather than developers (see `changelog.d/README.md`). Never edit `CHANGELOG.md` by hand for a new entry: one shared file made every open pull request conflict whenever another merged. The Release workflow puts the new entries at the top of the release notes. Before pushing any pull request, run `git fetch --tags origin` and `scripts/changelog.sh collect`: after a release it moves the released entries into `CHANGELOG.md` and removes their files, and the pull request commits the result.
- Once a pull request is merged or closed, delete its branch (remote and local) without asking. For a merged one, first check the branch tip matches the pull request's head.
- Never push to `main` or force-push it; it is protected.

## Working with the maintainer

- Work happens in Claude Code cloud sessions; the maintainer keeps no clone or tools on their Mac. Anything that needs a Mac (installing a build, Activity Monitor, crash logs, trying a change) is theirs to do: ask them, say exactly what to check, and wait for the result.
- **Hand checks:** anything CI can't verify goes in the pull request's "Check on a Mac" section as `- [ ]` checkboxes, each one concrete and checkable. When a release is published, `scripts/mac-checklist.sh` (run by the Release workflow) collects them into a "Check <version> on a Mac" issue for the maintainer to tick off. A failed check becomes its own bug issue, and its fix needs a regression test where one is possible. Before starting new work, look at open checklist issues for reported failures.
- Settled decisions, not to be raised again: Reelmark has one admin (the maintainer) and no paid Apple developer account, so no Developer ID signing or notarisation. Reported content is a feature of organization-owned repositories only, so conduct reports use the private reporting form.
- Where a platform standard exists (Apple's Human Interface Guidelines, macOS conventions, GitHub norms), pick it and do it, mentioning the choice in one line. Still ask before anything irreversible or outward-facing, such as secrets or account and repository settings.

## Sessions and handoffs

Work moves through a chain of sessions, each starting fresh. Context lives in the repository: this file for rules, issues for what and why, pull requests for what was done. Nothing important lives only in a chat.

- **Limits:** at most two pull requests open at a time. One session per batch of work, closed once its pull requests merge. When CI fails, read only the failing lines of its logs.
- **Picking work**, in this order: open pull requests that are red or conflicted; open bug issues, including failed "Check on a Mac" items; issues labelled `ready`; then the lowest-numbered open issue in the earliest open milestone. Skip issues labelled `needs-go-ahead` or `in-progress`, and the "Check … on a Mac" issues themselves (those are the maintainer's).
- **Claiming it:** label the issue `in-progress` before starting, and remove the label when its pull request merges or the work stops.
- **Staying on course:** one issue per session and nothing else. Anything unrelated that turns up becomes a new issue, not part of the pull request. A choice that this file, Apple's guidelines or the issue don't settle is asked on the issue, not guessed.
- **When stuck:** if CI is still red after three fix attempts, or the issue needs a decision, comment on the issue with what's wrong and what's needed, swap `in-progress` for `needs-go-ahead`, and move on to the next issue.
- **Handoff:** before finishing, comment on the issue: what shipped, what's left, anything surprising. Lessons every future session needs go into this file in its pull request.
- **Next session:** once its pull request has merged, a session starts the next one itself, without asking the maintainer: claude-code-remote `create_session` with `source_url` https://github.com/MineGene/reelmark, the same environment, tags `["reelmark-chain"]`, and the prompt "Read CLAUDE.md and continue the Reelmark work chain." Sessions started this way get the same GitHub connection. If `create_session` fails (for example at the limit of 8 sessions started one from another), fire the scheduled task "Reelmark daily pickup" instead (claude-code-remote `fire_trigger`, trigger `trig_01Aew24GjC6eNAbBLEuJpAvH`), which starts a fresh chain. The same task runs daily at 05:38 Sydney time to restart a stalled chain.
- **Ending:** every session ends its last message with one plain line: **"Safe to close this session"** once its pull request has merged, its handoff is posted and the next session has been started (with a link to it if available; if starting it failed, the exact prompt to paste instead: "Read CLAUDE.md and continue the Reelmark work chain." on MineGene/reelmark, Default environment); otherwise **"Keep this session open: <what it's waiting for>"**.
- Milestones don't stop the chain. It stops only when nothing is left to pick, and says so on the last issue it closed.
- "Check suite completed" notifications can arrive while required jobs are still queued, and often concern an older commit: read the check runs on the pull request's current head before acting.
- Only `api.github.com` paths under `repos/MineGene/reelmark` are reachable from a session, and they act as the session's GitHub account (MachineGene).

## Writing commits and pull requests

Commits and pull requests are a permanent record for people reading the history later, not a report of the session. Follow Git's own [SubmittingPatches](https://git-scm.com/docs/SubmittingPatches) and the Linux kernel's [Submitting patches](https://www.kernel.org/doc/html/latest/process/submitting-patches.html) for commits, and Google's [Writing good CL descriptions](https://google.github.io/eng-practices/review/developer/cl-descriptions.html) for pull requests. No Conventional Commits prefixes.

- **Subject:** imperative mood, completing "If applied, this commit will…" ("Add Redo to Copy and Move to Library"). About 50 characters, at most 72; capitalised; no full stop.
- **Body:** after a blank line, wrapped at 72 characters. Describe the problem first, then what the change does about it and why this way. It must make sense to someone who never saw the conversation.
- **Neutral voice:** no "you", "I", "we", "the user asked", "the maintainer picked" or narration of the session. State the reason itself: "Copies had no way back" rather than "The maintainer asked for undo".
- **Pull request description:** use the template's sections (Summary, Motivation, Changes, Testing, Check on a Mac). Link the issue it fixes ("Fixes #12"). Testing says what CI covers; Check on a Mac lists, as `- [ ]` checkboxes, what only a person on a Mac can verify.
- **Title:** the same rules as a commit subject; it becomes the squash commit's subject.

## Building and testing

- There is no Xcode here. GitHub Actions is the compiler and test runner: push, then read the check annotations (`scripts/annotate-errors.sh` turns errors into annotations with file and line).
- Target: macOS 26 or later, Apple silicon only, built with the Xcode pinned in `.xcode-version` (27.x) on GitHub's `xcode-27` runner image. The minimum is 26, not 27, only so the CodeQL scan can run: it doesn't support Xcode 27 yet, so it builds with Xcode 26.6 on `macos-26`. Keep code compatible with macOS 26; guard anything newer with `if #available(macOS 27, *)`.
- Core logic lives in `Packages/ReelmarkCore` with XCTest tests. Add tests for every behaviour change, and for every bug fixed a regression test that fails without the fix. When something can't be tested in CI (it needs a real drag from Finder, chosen library folders or a person's eyes), say so in the pull request's Testing section and list what to check by hand on a Mac. Tests use invented release names and empty placeholder files, never real media or the network.
- UI tests in `ReelmarkUITests/` launch a Debug build with `-ui-testing`, which fills the list with made-up items (`LibraryModel.forLaunch`, Debug only) and uses the window like a person would. Add one for every window change, especially anything that removes or changes rows.
  - Pass test settings such as a list size through the launch environment (`REELMARK_UI_TEST_ITEMS`), never as launch arguments: macOS reads a bare number as a file to open, and the window never appears.
  - XCUITest calls table headers not hittable: click them by coordinate, and pause a second between two clicks.
  - GitHub's macOS runners are slow and queue jobs, so expect long waits for checks.
  - A UI test that opens a file with the app (`app.open`) can make macOS launch a second copy; quit every copy by bundle identifier afterwards (see `testOpeningAVideoWithReelmarkAddsIt`).
  - Dragging a window corner never resizes the window on GitHub's runners; window-size changes are hand checks.
  - The accessibility audit flags table cells that are hidden from accessibility or made elements without a role: name every cell and give hand-made elements a role.
- Keep SwiftUI view bodies short: a new modifier or handler goes in a small method or subview (as `ContentView` is laid out), never at the end of a long chain. The code scan builds with Xcode 26.6, whose type checker gives up on long chains ("unable to type-check this expression in reasonable time") that Xcode 27 still accepts, so this fails only Analyze Swift. When it does, read the exact error line before changing anything.
- The Xcode project uses a synchronized folder: new Swift files in `Reelmark/` need no project edit.
- Builds must stay reproducible: the *Reproducible build* check builds twice at different paths and compares `scripts/app-digest.sh` output. Never add timestamps, absolute paths or run-specific values to the build.

## Rules the design depends on

- **Privacy:** only a cleaned-up title and year (plus a TMDB access token) are sent, and only to `api.themoviedb.org`, over HTTPS, with an ephemeral session (no cache, cookies or credential storage). File names, paths and anything else about the user's files never leave the Mac and are never logged or written to disk. `scripts/check-app.sh` fails if any other web address appears in the app. The one exception is Help › Report a Bug… / Request a Feature…: it previews a summary (versions, Mac model, settings, list counts, crash and hang summaries from MetricKit, never names, paths or tokens) and only on the person's click opens `https://github.com/MineGene/reelmark/issues/new` in their browser; the app never fetches it. There are no analytics or background reports of any kind.
- **Permissions:** sandboxed with exactly four entitlements (sandbox, outgoing network, user-selected read-write, app-scoped bookmarks). `scripts/check-app.sh` enforces the list.
- **Never destroy data:** never overwrite an existing file; never delete anything. Moving is opt-in (Copy is the default). The one exception is Edit ▸ Undo, which works like Finder's: it sends copies Reelmark made to the Trash (only while the original still exists), never deletes them outright.
- **Tokens:** Reelmark ships with its own read-only TMDB token (`TMDBKey.swift`). It is public on purpose: anything in an open-source app can be read out of it. A person's own token, if they add one in Settings, is used instead and lives only in the Keychain (`Keychain.swift`), never in preferences or files.
- **Memory:** the app runs on an 8 GB MacBook Neo alongside Jellyfin. Keep it tiny: no artwork or images, no file contents read, at most four lookups at a time (`LibraryModel.parallelLookups`, well within TMDB's limits), each title looked up once, results cached only for the session, the app quits when its window closes.
- **Design:** standard SwiftUI and AppKit controls only, following Apple's Human Interface Guidelines, so the app picks up macOS's own look, light and dark mode and accessibility. No custom colours, fonts or chrome.
- **No third-party code** in the app or as a package dependency. No new build or test tool without a stated reason, a pinned version and a checksum.
- Keep code simple and commented where the why isn't obvious; the maintainer makes high-level decisions and doesn't read every line.
