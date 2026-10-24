#!/bin/bash
# Opens a "Check <version> on a Mac" issue listing the hand checks from
# every pull request in a release: the checkboxes in each pull request's
# "Check on a Mac" section. Some things CI can't test (real drags from
# Finder, chosen library folders, how it looks), so this makes sure each
# one reaches the maintainer's Mac and gets ticked off.
#
# Usage: scripts/mac-checklist.sh <version>          (needs gh and GH_TOKEN)
#        scripts/mac-checklist.sh --extract < body   (prints a body's checks)
set -euo pipefail

# The "- [ ]" lines under a "## Check on a Mac" heading, up to the next
# heading. HTML comments (the template's hints) are dropped.
extract() {
  awk '
    /^## / { inside = ($0 ~ /^## Check on a Mac[[:space:]]*$/); next }
    inside && /^[[:space:]]*- \[ \]/ { print }
  '
}

if [ "${1:-}" = "--extract" ]; then
  extract
  exit 0
fi

version="${1:?usage: mac-checklist.sh <version>}"
tag="v$version"
# The release before this one, by version order.
previous=$(git tag --list 'v*' --sort=-v:refname | grep -A1 -x "$tag" | sed -n 2p || true)
range="${previous:+$previous..}$tag"

# Squash merges end their subject with "(#123)".
numbers=$(git log --format=%s "$range" | sed -nE 's/.*\(#([0-9]+)\)$/\1/p')

body=""
for number in $numbers; do
  pr=$(gh pr view "$number" --json title,body,url)
  checks=$(jq -r .body <<<"$pr" | tr -d '\r' | extract)
  [ -n "$checks" ] || continue
  title=$(jq -r .title <<<"$pr")
  url=$(jq -r .url <<<"$pr")
  body+="## [$title]($url)"$'\n\n'"$checks"$'\n\n'
done

if [ -z "$body" ]; then
  echo "No hand checks in $tag."
  exit 0
fi

{
  echo "Checks for [$version](https://github.com/$GITHUB_REPOSITORY/releases/tag/$tag) that CI can't do. Install it, then tick each box. Anything that fails gets its own bug report, linked next to its box."
  echo
  printf '%s' "$body"
} > mac-checklist.md
gh issue create --title "Check $version on a Mac" --body-file mac-checklist.md
