#!/bin/bash
# Changelog entries, one small file per pull request.
#
# A pull request that changes what people see or can do adds its entry as
# changelog.d/<branch>.md, with Keep a Changelog groups:
#
#   ### Added
#
#   - A search field in the toolbar narrows the list.
#
# Editing CHANGELOG.md itself in every pull request made each merge
# conflict with every other open one. The files are gathered later:
#
#   scripts/changelog.sh check            # entry files are well formed (CI)
#   scripts/changelog.sh notes 1.2.3      # the version's section, for the
#                                         # release notes (Release workflow)
#   scripts/changelog.sh collect          # move released entries into
#                                         # CHANGELOG.md (the first pull
#                                         # request after a release)
#
# An entry belongs to the first release made after the commit that added
# it. Workflows can't push to the protected main branch, so collect runs
# in a pull request rather than in the Release workflow.
set -euo pipefail
cd "$(dirname "$0")/.."

dir=changelog.d
groups=(Added Changed Deprecated Removed Fixed Security)
repo_url=https://github.com/MineGene/reelmark
tag_glob='v[0-9]*.[0-9]*.[0-9]*'

# Entry files added between two commits (renames count as edits).
added_entries() {
  git diff --no-renames --name-only --diff-filter=A "$1" "$2" -- "$dir" \
    | grep -E "^$dir/[^/]+\.md$" | grep -v "^$dir/README\.md$" | sort || true
}

# The day a commit was made, in UTC, so every machine agrees.
commit_day() {
  TZ=UTC git log -1 --date=format-local:%Y-%m-%d --format=%cd "$1"
}

# "## [version] - day" and the entries added between two commits, grouped
# in Keep a Changelog's order. Prints nothing if there are none.
section() {
  local version=$1 from=$2 to=$3 files body="" group items f
  files=$(added_entries "$from" "$to")
  [ -n "$files" ] || return 0
  for group in "${groups[@]}"; do
    items=""
    for f in $files; do
      items+=$(git show "$to:$f" | awk -v want="### $group" '
        /^### / { inside = ($0 == want); next }
        inside && NF { print }')
      items+=$'\n'
    done
    items=$(grep -v '^$' <<<"$items" || true)
    [ -z "$items" ] || body+=$'\n'"### $group"$'\n\n'"$items"$'\n'
  done
  printf '## [%s] - %s\n%s\n' "$version" "$(commit_day "$to")" "$body"
}

check() {
  local f status=0 line n group bullets
  for f in "$dir"/*.md; do
    [ -e "$f" ] || continue
    [ "$f" != "$dir/README.md" ] || continue
    n=0 group="" bullets=0
    while IFS= read -r line || [ -n "$line" ]; do
      n=$((n + 1))
      case "$line" in
        "")
          ;;
        "### "*)
          group=${line#\#\#\# }
          if [[ " ${groups[*]} " != *" $group "* ]]; then
            echo "::error file=$f,line=$n::Unknown group \"$group\": use one of ${groups[*]}."
            status=1
          fi
          ;;
        "- "*)
          if [ -z "$group" ]; then
            echo "::error file=$f,line=$n::Put entries under a group heading such as \"### Added\"."
            status=1
          fi
          bullets=$((bullets + 1))
          ;;
        "  "*)
          ;; # an entry continued on the next line
        *)
          echo "::error file=$f,line=$n::Expected \"### Group\", \"- entry\" or a blank line."
          status=1
          ;;
      esac
    done <"$f"
    if [ "$bullets" -eq 0 ]; then
      echo "::error file=$f::No entries: add at least one \"- \" line."
      status=1
    fi
  done
  return "$status"
}

notes() {
  local version=${1:?Usage: changelog.sh notes <version> [commit]} to=${2:-HEAD} last
  last=$(git describe --tags --abbrev=0 --match "$tag_glob" "$to" 2>/dev/null || true)
  [ -n "$last" ] || return 0
  section "${version#v}" "$last" "$to"
}

collect() {
  local newest tags=() previous tag s sections="" links="" files="" f
  newest=$(grep -m 1 -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | tr -d '#[] ')
  [ -n "$newest" ] || { echo "No released version found in CHANGELOG.md." >&2; exit 1; }
  git rev-parse -q --verify "refs/tags/v$newest" >/dev/null \
    || { echo "Tag v$newest is missing: run git fetch --tags first." >&2; exit 1; }

  # Releases after the newest one in CHANGELOG.md, oldest first.
  previous="v$newest"
  while IFS= read -r tag; do
    tags+=("$tag")
  done < <(git tag --list "$tag_glob" --sort=v:refname \
    | awk -v from="$previous" 'found { print } $0 == from { found = 1 }')
  [ "${#tags[@]}" -gt 0 ] || { echo "CHANGELOG.md is up to date." >&2; return 0; }

  # Sections and links are listed newest first.
  for tag in "${tags[@]}"; do
    s=$(section "${tag#v}" "$previous" "$tag")
    [ -z "$s" ] || sections="$s"$'\n\n'"$sections"
    links="[${tag#v}]: $repo_url/compare/$previous...$tag"$'\n'"$links"
    files+="$(added_entries "$previous" "$tag")"$'\n'
    previous=$tag
  done

  SECTIONS=$sections LINKS=$links LATEST=$previous awk '
    BEGIN { sections = ENVIRON["SECTIONS"]; links = ENVIRON["LINKS"] }
    # New sections go just before the newest released one.
    !placed && /^## \[[0-9]/ { printf "%s", sections; placed = 1 }
    /^\[Unreleased\]: / {
      print "[Unreleased]: '"$repo_url"'/compare/" ENVIRON["LATEST"] "...HEAD"
      printf "%s", links
      next
    }
    { print }
  ' CHANGELOG.md >CHANGELOG.md.new
  mv CHANGELOG.md.new CHANGELOG.md

  # The entries now live in CHANGELOG.md; files already gone are skipped.
  for f in $files; do
    [ ! -e "$f" ] || git rm -q "$f"
  done
  echo "Added ${tags[*]} to CHANGELOG.md." >&2
}

case "${1:-}" in
  check) check ;;
  notes) shift; notes "$@" ;;
  collect) collect ;;
  *) echo "Usage: scripts/changelog.sh check | notes <version> [commit] | collect" >&2; exit 2 ;;
esac
