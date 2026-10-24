#!/bin/bash
# Tests scripts/next-version.sh in a throwaway repository with made-up
# releases and changelog entries. Run by CI; needs only git and bash.
set -euo pipefail
script="$(cd "$(dirname "$0")" && pwd)/next-version.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

fail() { echo "::error::test-next-version: $*"; exit 1; }
expect() { # expect <name> <expected> <actual>
  [ "$2" = "$3" ] || fail "$1: expected '$2', got '$3'"
}
next() { scripts/next-version.sh "$@" 2>/dev/null; }
commit() { git add . && git commit -qm "$1"; }

git init -q
git config user.name Test
git config user.email test@users.noreply.github.com
git config commit.gpgsign false
mkdir scripts changelog.d Reelmark docs
cp "$script" scripts/next-version.sh
echo "Entries go here." >changelog.d/README.md
echo "app" >Reelmark/App.swift
commit "Start"

expect "first release" "0.1.0" "$(next)"
git tag v0.1.0

echo "docs" >docs/page.md
commit "Docs only"
expect "docs alone make no release" "" "$(next)"

echo "fix" >>Reelmark/App.swift
printf '### Fixed\n\n- Clearing works again.\n' >changelog.d/clear.md
commit "Fix clearing"
expect "a fix bumps the patch" "0.1.1" "$(next)"

echo "change" >>Reelmark/App.swift
commit "Refactor without an entry"
expect "no entry bumps the patch" "0.1.1" "$(next)"

printf '### Security\n\n- Tokens stay in the Keychain.\n' >changelog.d/token.md
commit "Security fix"
expect "security fixes bump the patch" "0.1.1" "$(next)"
git tag v0.1.1

echo "feature" >>Reelmark/App.swift
printf '### Fixed\n\n- Sorting is stable.\n\n### Added\n\n- A search field.\n' >changelog.d/search.md
commit "Add search"
expect "an Added entry bumps the minor" "0.2.0" "$(next)"

expect "a requested version wins" "1.0.0" "$(next 1.0.0)"
expect "a requested v-prefix is dropped" "0.3.0" "$(next v0.3.0)"
git tag v0.2.0

echo "change" >>Reelmark/App.swift
printf '### Changed\n\n- Copy is the default.\n' >changelog.d/copy.md
commit "Change default"
expect "a Changed entry bumps the minor" "0.3.0" "$(next)"
git tag v0.3.0

echo "fix" >>Reelmark/App.swift
printf '### Fixed\n\n- An entry that mentions ### Added in passing.\n' >changelog.d/mention.md
commit "Fix with a mention"
expect "only real headings count" "0.3.1" "$(next)"

echo "All next-version tests passed."
