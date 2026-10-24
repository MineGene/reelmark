# Changelog entries

A pull request that changes what people see or can do adds one file here, named after its branch (for example `search-field.md`), instead of editing [CHANGELOG.md](../CHANGELOG.md). Separate files mean open pull requests never conflict over the changelog.

Use the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) groups (Added, Changed, Deprecated, Removed, Fixed, Security), and write for people using the app rather than developers:

```markdown
### Added

- A search field in the toolbar (⌘F) narrows a long list to the files, matches or new names containing what you type.
```

The Release workflow puts the entries added since the last release at the top of the new release's notes. Workflows can't push to `main`, so the first pull request after a release runs `scripts/changelog.sh collect`, which moves released entries into CHANGELOG.md and removes their files. `scripts/changelog.sh check` (run by CI) makes sure each file is well formed.
