# Security policy

## Reporting a vulnerability

Please report privately using GitHub's **[Report a vulnerability](https://github.com/MineGene/reelmark/security/advisories/new)** button (Security tab). Don't open a public issue. Include the Reelmark version, macOS version and steps to reproduce. Never attach your own media files or your TMDB token.

## Supported versions

Only the latest release receives fixes. Reelmark doesn't update itself or check for updates, so security fixes are clearly marked in release notes.

## Design

- Sandboxed, with exactly four entitlements: sandbox, outgoing connections, user-selected files (read-write) and bookmarks for the chosen library folders. CI fails any build with a different set.
- Network: HTTPS to `api.themoviedb.org` only, TLS 1.2 or later, ephemeral session (no cache, cookies or credential storage). CI fails a build containing any other web address.
- Sends only a title and year, plus the user's TMDB token. The token is kept in the Keychain.
- Never overwrites or deletes files; moving instead of copying is opt-in.
- Hardened runtime; no JIT, unsigned memory or library-validation exceptions. No third-party code.
- GitHub Actions are pinned to commit SHAs; Dependabot updates them after a 7-day cooldown. Releases are built only from `main` by GitHub Actions, reproducibly, with a public build attestation. Rebuilding gives the same app byte for byte, except the pixels of the app icon's pre-rendered pictures, which Xcode renders slightly differently each time; their names and sizes, and all code, must still match exactly.
