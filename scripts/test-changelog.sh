#!/bin/bash
# Tests scripts/changelog.sh in a throwaway repository with made-up
# releases and entries. Run by CI; needs only git and bash.
set -euo pipefail
script="$(cd "$(dirname "$0")" && pwd)/changelog.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

fail() { echo "::error::test-changelog: $*"; exit 1; }
expect() { # expect <name> <expected> <actual>
  [ "$2" = "$3" ] || fail "$1"$'\n--- expected\n'"$2"$'\n--- got\n'"$3"
}

git init -q
git config user.name Test
git config user.email test@users.noreply.github.com
git config commit.gpgsign false
mkdir scripts changelog.d
cp "$script" scripts/changelog.sh
export GIT_COMMITTER_DATE="2026-01-02T03:00:00Z" GIT_AUTHOR_DATE="2026-01-02T03:00:00Z"

cat >CHANGELOG.md <<'EOF'
# Changelog

## [Unreleased]

Entries for changes not yet released are in changelog.d.

## [1.0.0] - 2026-01-01

### Added

- First release.

[Unreleased]: https://github.com/MineGene/reelmark/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/MineGene/reelmark/releases/tag/v1.0.0
EOF
echo "Entries go here." >changelog.d/README.md
git add . && git commit -qm "Start" && git tag v1.0.0

# Two pull requests merged, then a release.
printf '### Fixed\n\n- Clearing works again.\n' >changelog.d/clear.md
git add . && git commit -qm "Fix clearing"
printf '### Added\n\n- A search field.\n  It narrows the list.\n\n### Fixed\n\n- Sorting is stable.\n' >changelog.d/search.md
git add . && git commit -qm "Add search"

expect "notes for the next release" "## [1.1.0] - 2026-01-02

### Added

- A search field.
  It narrows the list.

### Fixed

- Clearing works again.
- Sorting is stable." "$(scripts/changelog.sh notes v1.1.0)"
git tag v1.1.0

# A release with no entries, then one more entry and release.
export GIT_COMMITTER_DATE="2026-01-03T23:30:00Z"
git commit -q --allow-empty -m "Internal change" && git tag v1.1.1
printf '### Changed\n\n- Faster lookups.\n' >changelog.d/fast.md
git add . && git commit -qm "Speed up" && git tag v1.1.2
# Merged after the last release: stays a file.
printf '### Added\n\n- Not released yet.\n' >changelog.d/later.md
git add . && git commit -qm "Later"

expect "no notes without entries" "" "$(scripts/changelog.sh notes 1.1.1 v1.1.1)"
scripts/changelog.sh check || fail "check rejected good entries"
scripts/changelog.sh collect 2>/dev/null

expect "collected CHANGELOG.md" "# Changelog

## [Unreleased]

Entries for changes not yet released are in changelog.d.

## [1.1.2] - 2026-01-03

### Changed

- Faster lookups.

## [1.1.0] - 2026-01-02

### Added

- A search field.
  It narrows the list.

### Fixed

- Clearing works again.
- Sorting is stable.

## [1.0.0] - 2026-01-01

### Added

- First release.

[Unreleased]: https://github.com/MineGene/reelmark/compare/v1.1.2...HEAD
[1.1.2]: https://github.com/MineGene/reelmark/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/MineGene/reelmark/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/MineGene/reelmark/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/MineGene/reelmark/releases/tag/v1.0.0" "$(cat CHANGELOG.md)"
expect "released entry files removed" "changelog.d/README.md
changelog.d/later.md" "$(ls changelog.d/* | sort)"

# Running it again changes nothing.
before=$(cat CHANGELOG.md)
scripts/changelog.sh collect 2>/dev/null
expect "collect is idempotent" "$before" "$(cat CHANGELOG.md)"

# Badly formed entries are caught.
printf -- '- No group.\n' >changelog.d/bad1.md
printf '### Improved\n\n- Wrong group.\n' >changelog.d/bad2.md
printf '### Added\n\nJust prose.\n' >changelog.d/bad3.md
out=$(scripts/changelog.sh check) && fail "check accepted bad entries"
for want in "bad1.md,line=1::Put entries under a group" "bad2.md,line=1::Unknown group" \
  "bad3.md,line=3::Expected" "bad3.md::No entries"; do
  grep -qF "$want" <<<"$out" || fail "check didn't report $want"$'\n'"$out"
done

echo "changelog.sh: all tests passed."
