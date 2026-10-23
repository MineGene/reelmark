#!/bin/bash
# Prints the version the Release workflow should publish, or nothing if
# there's nothing new to release.
#
#   scripts/next-version.sh          # automatic: next patch version, but only
#                                    # if the app itself changed since the
#                                    # last release (0.1.0 if there is none)
#   scripts/next-version.sh 0.2.0    # a chosen version, e.g. for bigger changes
#
# Changes to docs, tests or CI alone don't make a new release: users would
# get an identical app.
set -euo pipefail
cd "$(dirname "$0")/.."

requested="${1:-}"
requested="${requested#v}"
last=$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -n 1)

if [ -n "$requested" ]; then
  [[ "$requested" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || { echo "::error::Version must look like 1.2.3" >&2; exit 1; }
  if git rev-parse -q --verify "refs/tags/v$requested" >/dev/null; then
    echo "::error::v$requested has already been released." >&2; exit 1
  fi
  echo "$requested"
  exit 0
fi

if [ -z "$last" ]; then
  echo "0.1.0"
  exit 0
fi

# Files that end up in, or decide what goes into, the app.
app='^(Reelmark/|Packages/ReelmarkCore/Sources/|Packages/ReelmarkCore/Package\.swift$|Config/|Reelmark\.xcodeproj/|\.xcode-version$)'
if git diff --name-only "$last" HEAD | grep -qE "$app"; then
  IFS=. read -r major minor patch <<<"${last#v}"
  echo "$major.$minor.$((patch + 1))"
else
  echo "No changes to the app since $last; nothing to release." >&2
fi
