# Reelmark

Drop in downloaded movies and TV episodes. Reelmark identifies each one on The Movie Database and files it into your Jellyfin library with exactly the names Jellyfin expects:

```
Movies/Dune - Part Two (2024) [tmdbid-693134]/Dune - Part Two (2024) [tmdbid-693134].mkv
Shows/Severance (2022) [tmdbid-95396]/Season 01/Severance S01E02.mkv
```

The TMDB id in each folder name tells Jellyfin precisely which title it is, so remakes, same-named shows and foreign titles are never mixed up.

- Native macOS app for Apple silicon, macOS 26 or later (built for macOS 27)
- Free and open source (MIT), no account, no tracking, no ads
- Drop single files or whole download folders; sample clips are skipped
- Pick a different match from a list, or search again by hand
- Copy (default, so your torrent client can keep seeding) or move
- Never overwrites anything, never deletes anything

## Install

Download the DMG from [Releases](https://github.com/MineGene/reelmark/releases) and follow the steps in the release notes. Reelmark isn't notarised by Apple (that needs a paid developer account), so the first launch needs **Open Anyway** in System Settings › Privacy & Security.

You'll need a free TMDB access token: create an account at [themoviedb.org](https://www.themoviedb.org/signup), open [Settings › API](https://www.themoviedb.org/settings/api), and copy the **API Read Access Token** into Reelmark › Settings. It's stored in your Keychain.

## Privacy

- The only thing Reelmark sends anywhere is a title and year — for example "Severance" — to TMDB's API, with your token. File names, folders and everything else stay on your Mac.
- No analytics, no crash reporting, no update checks, nothing written about your files.
- Sandboxed: Reelmark can only touch files you drop in and the two library folders you choose.
- Every release is checked automatically: exact permissions, TMDB as the only web address in the app, and a reproducible build anyone can verify with `scripts/verify-release.sh` (everything matches exactly except the pixels of the app icon's pre-rendered pictures).

## How it's made

Reelmark is written almost entirely by Claude (Anthropic's AI) through Claude Code, under the maintainer's direction, and built, tested and released by GitHub Actions — nothing is built on a personal machine. See [CONTRIBUTING.md](CONTRIBUTING.md) for how changes are checked.

This product uses the TMDB API but is not endorsed or certified by TMDB.
