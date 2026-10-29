#!/bin/bash
# Tests scripts/ci-changes.sh in a throwaway repository with made-up
# pull requests. Run by CI; needs only git and bash.
set -euo pipefail
script="$(cd "$(dirname "$0")" && pwd)/ci-changes.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

fail() { echo "::error::test-ci-changes: $*"; exit 1; }

git init -q -b main
git config user.name Test
git config user.email test@users.noreply.github.com
git config commit.gpgsign false
mkdir scripts
cp "$script" scripts/ci-changes.sh
echo "Read me." >README.md
mkdir Reelmark && echo "<plist/>" >Reelmark/PrivacyInfo.xcprivacy
git add . && git commit -qm "Start"
base=$(git rev-parse HEAD)

# expect <true|false> <path changed by a pull request>
prs=0
expect() {
  prs=$((prs + 1))
  git checkout -q -b "pr-$prs" "$base"
  mkdir -p "$(dirname "$2")"
  echo "# changed" >>"$2"
  git add "$2" && git commit -qm "Change $2"
  local got
  got=$(scripts/ci-changes.sh "$base" HEAD)
  [ "$got" = "$1" ] || fail "$2: expected $1, got $got"
  git checkout -q main
}

# Pull requests that change only these skip the macOS jobs.
expect false README.md
expect false CONTRIBUTING.md
expect false changelog.d/some-branch.md
expect false docs/screenshot.png
expect false scripts/changelog.sh
expect false scripts/test-ci-changes.sh
expect false .github/workflows/release.yml
expect false .github/pull_request_template.md
expect false .coderabbit.yaml

# Anything that goes into the app, tests it, or runs in those jobs.
expect true Reelmark/ContentView.swift
expect true Reelmark/Assets.xcassets/Contents.json
expect true Packages/ReelmarkCore/Sources/ReelmarkCore/Parser.swift
expect true Packages/ReelmarkCore/Tests/ReelmarkCoreTests/ParserTests.swift
expect true Packages/ReelmarkCore/Package.swift
expect true ReelmarkUITests/ReelmarkUITests.swift
expect true Config/Info.plist
expect true Reelmark.xcodeproj/project.pbxproj
expect true .xcode-version
expect true .swift-format
expect true scripts/build-app.sh
expect true scripts/check-app.sh
expect true scripts/check-reproducible.sh
expect true scripts/app-digest.sh
expect true scripts/select-xcode.sh
expect true scripts/annotate-errors.sh
expect true scripts/ci-changes.sh
expect true .github/workflows/ci.yml
expect true .github/workflows/codeql.yml
expect true Somewhere/Else.swift
# Git quotes non-ASCII paths unless asked not to.
expect true "Reelmark/Épisode.txt"

# Moving a file out of the app changes the app.
git checkout -q -b renamed "$base"
mkdir -p docs && git mv Reelmark/PrivacyInfo.xcprivacy docs/PrivacyInfo.xcprivacy
git commit -qm "Move"
[ "$(scripts/ci-changes.sh "$base" HEAD)" = true ] || fail "moving a file out of the app should run"
git checkout -q main

# A docs change plus an app change still runs.
git checkout -q -b mixed "$base"
echo "changed" >>README.md
mkdir -p Reelmark && echo "changed" >Reelmark/App.swift
git add README.md Reelmark/App.swift && git commit -qm "Both"
[ "$(scripts/ci-changes.sh "$base" HEAD)" = true ] || fail "docs and app together should run"
git checkout -q main

# No pull request, or commits git can't compare: run everything.
[ "$(scripts/ci-changes.sh)" = true ] || fail "no commits given should run"
[ "$(scripts/ci-changes.sh 0000000000000000000000000000000000000000 HEAD)" = true ] \
  || fail "an unknown base should run"

echo "ci-changes.sh: all tests passed"
