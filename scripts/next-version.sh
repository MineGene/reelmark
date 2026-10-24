#!/bin/bash
# Prints the version the Release workflow should publish, or nothing if
# there's nothing new to release.
#
#   scripts/next-version.sh          # automatic, but only if the app itself
#                                    # changed since the last release (0.1.0
#                                    # if there is none): the next minor
#                                    # version if the changelog entries being
#                                    # released add or change features, else
#                                    # the next patch version
#   scripts/next-version.sh 0.2.0    # a chosen version, e.g. for bigger changes
#
# Changes to docs, tests or CI alone don't make a new release: users would
# get an identical app.
#
# The bump follows Semantic Versioning: an entry under Added, Changed,
# Deprecated or Removed in changelog.d (see changelog.sh) is a new or
# changed feature, so the minor version goes up (0.1.18 -> 0.2.0); Fixed
# and Security entries alone are fixes, so only the patch does.
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
# Capture first, so grep stopping early can't fail the pipe (see check-app.sh).
changed=$(git diff --name-only "$last" HEAD)
if grep -qE "$app" <<<"$changed"; then
  IFS=. read -r major minor patch <<<"${last#v}"
  # Entry files added since the last release, as changelog.sh finds them.
  entries=$(git diff --no-renames --name-only --diff-filter=A "$last" HEAD -- changelog.d \
    | grep -E '^changelog\.d/[^/]+\.md$' | grep -v '^changelog\.d/README\.md$' || true)
  feature=false
  for f in $entries; do
    if git show "HEAD:$f" | grep -qE '^### (Added|Changed|Deprecated|Removed)[[:space:]]*$'; then
      feature=true
    fi
  done
  if $feature; then
    echo "$major.$((minor + 1)).0"
  else
    echo "$major.$minor.$((patch + 1))"
  fi
else
  echo "No changes to the app since $last; nothing to release." >&2
fi
