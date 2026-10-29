#!/bin/bash
# Prints "true" if the macOS CI jobs (tests, app build and checks, code
# scan) need to run, or "false" if a pull request changes nothing they
# build, test or run, such as docs alone. Run by the CI and CodeQL
# workflows, whose macOS jobs are skipped on "false".
#
#   scripts/ci-changes.sh BASE HEAD   # a pull request's base and head
#   scripts/ci-changes.sh             # no pull request: always "true"
#
# When in doubt (no commits given, or git can't compare them) it prints
# "true": running a job for nothing costs minutes, skipping one wrongly
# lets a broken app through.
set -uo pipefail
cd "$(dirname "$0")/.."

base="${1:-}"
head="${2:-}"
if [ -z "$base" ] || [ -z "$head" ]; then
  echo true
  exit 0
fi

# The app's own files (as in scripts/next-version.sh), its tests, any
# Swift, and the scripts and workflows the macOS jobs run.
needs='^(Reelmark/|Packages/|ReelmarkUITests/|Config/|Reelmark\.xcodeproj/|\.xcode-version$|\.swift-format$|scripts/(annotate-errors|app-digest|build-app|check-app|check-reproducible|select-xcode|ci-changes)\.sh$|\.github/workflows/(ci|codeql)\.yml$)|\.swift$'

# Capture first, so a failed diff falls back to running, and grep stopping
# early can't fail the pipe (see check-app.sh).
changed=$(git diff --name-only "$base...$head" 2>/dev/null) || { echo true; exit 0; }
if grep -qE "$needs" <<<"$changed"; then
  echo true
else
  echo false
fi
