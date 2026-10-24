#!/bin/bash
# Promotes a checked pre-release to the latest stable release: the weekly
# release train. Every merged app change is published as a pre-release
# (release.yml), and its hand checks open a "Check <version> on a Mac"
# issue (mac-checklist.sh). A version is checked once that issue is
# closed, or if it had no hand checks.
#
# Each version contains every change before it, so this promotes the
# newest pre-release for which it and all pre-releases since the current
# stable release are checked. Promoting only edits the release: the build,
# its checksum and its signed build record stay exactly as published.
#
# Usage: scripts/promote-release.sh            the weekly run
#        scripts/promote-release.sh 0.1.12     promote this version now,
#                                              checked or not (urgent fixes)
# Needs gh, jq and GH_TOKEN, and GITHUB_REPOSITORY (owner/name).
set -euo pipefail

repo="${GITHUB_REPOSITORY:?set GITHUB_REPOSITORY to owner/name}"
releases=$(gh release list --repo "$repo" --limit 100 --json tagName,isPrerelease,isLatest)

if [ -n "${1:-}" ]; then
  target="v${1#v}"
  jq -e --arg t "$target" 'any(.[]; .tagName == $t)' <<<"$releases" >/dev/null \
    || { echo "::error::There's no release $target."; exit 1; }
  echo "Promoting $target by hand."
else
  latest=$(jq -r '.[] | select(.isLatest) | .tagName' <<<"$releases")
  # Pre-releases newer than the stable release, oldest first.
  newer=$(jq -r '.[] | select(.isPrerelease) | .tagName' <<<"$releases" \
    | { cat; [ -n "$latest" ] && echo "$latest"; } | sort -V \
    | sed -n "/^${latest:-NONE}\$/,\$p" | grep -vx "${latest:-NONE}" || true)
  target=""
  for tag in $newer; do
    version="${tag#v}"
    title="Check $version on a Mac"
    state=$(gh issue list --repo "$repo" --state all --search "\"$title\" in:title" \
      --json title,state --jq ".[] | select(.title == \"$title\") | .state" | head -1)
    if [ -z "$state" ] || [ "$state" = "CLOSED" ]; then
      target="$tag"
    else
      echo "$tag isn't checked yet (\"$title\" is open), so nothing newer is promoted."
      break
    fi
  done
  if [ -z "$target" ]; then
    echo "Nothing to promote: the stable release is ${latest:-none}."
    exit 0
  fi
fi

gh release edit "$target" --repo "$repo" --prerelease=false --latest
echo "$target is now the latest stable release."
