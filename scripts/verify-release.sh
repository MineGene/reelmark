#!/bin/bash
# Verifies a Reelmark release without trusting the maintainer, the AI that
# wrote the code, or the download page. Run it on a Mac:
#
#   scripts/verify-release.sh 0.1.1            # check the download
#   scripts/verify-release.sh 0.1.1 --rebuild  # also rebuild from source
#
# It checks that:
#   1. the DMG matches its published SHA-256 checksum
#   2. GitHub's signed build record (attestation, logged publicly by Sigstore)
#      says this DMG and its app digest were built by this repository's
#      release workflow (needs the GitHub CLI, "gh")
#   3. the app inside the DMG matches the attested app digest
#   4. the app is sandboxed with only the permissions it needs, and talks
#      to nothing but The Movie Database
#   5. with --rebuild: building the release's source with the pinned Xcode
#      gives exactly the same app
set -euo pipefail

repo="MineGene/reelmark"
version="${1:?usage: verify-release.sh <version, e.g. 0.1.1> [--rebuild]}"
version="${version#v}"
rebuild="${2:-}"

here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
mount=""
cleanup() {
  [ -n "$mount" ] && hdiutil detach -quiet "$mount" 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT

pass() { echo "  ✓ $*"; }
fail() { echo "  ✗ $*"; exit 1; }

dmg="Reelmark-$version.dmg"
digest="Reelmark-$version-app-digest.txt"
base="https://github.com/$repo/releases/download/v$version"

echo "Downloading release v$version…"
for f in "$dmg" "$dmg.sha256" "$digest"; do
  curl --fail --silent --show-error --location --proto '=https' -o "$work/$f" "$base/$f" \
    || fail "couldn't download $f (does v$version exist?)"
done

echo "1. Checksum"
(cd "$work" && shasum -a 256 -c "$dmg.sha256" >/dev/null) || fail "the DMG doesn't match its checksum"
pass "the DMG matches its published SHA-256"

echo "2. Build record (attestation)"
if command -v gh >/dev/null; then
  for f in "$dmg" "$digest"; do
    gh attestation verify "$work/$f" --repo "$repo" >/dev/null 2>&1 \
      || fail "no valid attestation for $f from $repo"
  done
  pass "both files were built by $repo's release workflow (Sigstore-signed)"
else
  echo "  – skipped: install the GitHub CLI (gh) to check this, or check by hand at"
  echo "    https://github.com/$repo/attestations"
fi

echo "3. The app inside the DMG"
mount=$(hdiutil attach -nobrowse -readonly -noautoopen "$work/$dmg" | awk -F'\t' '/\/Volumes\// {print $NF}')
[ -d "$mount/Reelmark.app" ] || fail "no Reelmark.app inside the DMG"
"$here/app-digest.sh" "$mount/Reelmark.app" > "$work/actual-digest.txt"
diff -q "$work/$digest" "$work/actual-digest.txt" >/dev/null \
  || fail "the app in the DMG doesn't match the attested app digest"
pass "the app matches the attested digest, file by file"

echo "4. Permissions"
"$here/check-app.sh" "$mount/Reelmark.app" >/dev/null \
  || fail "the app's permissions or web addresses aren't what Reelmark promises (run scripts/check-app.sh for details)"
pass "sandboxed, only the expected permissions, and TMDB is its only web address"

if [ "$rebuild" = "--rebuild" ]; then
  echo "5. Rebuild from source"
  git clone --quiet "https://github.com/$repo.git" "$work/src"
  git -C "$work/src" checkout --quiet "v$version"
  xcode=$(cd "$work/src" && scripts/select-xcode.sh) \
    || fail "the rebuild needs Xcode $(cat "$work/src/.xcode-version"), as pinned in .xcode-version"
  (cd "$work/src" && eval "$(tail -n 1 <<<"$xcode")" \
    && REELMARK_VERSION="$version" scripts/build-app.sh >/dev/null \
    && scripts/app-digest.sh build/Release/Reelmark.app) > "$work/rebuilt-digest.txt" \
    || fail "the rebuild failed"
  diff -q "$work/$digest" "$work/rebuilt-digest.txt" >/dev/null \
    || fail "rebuilding v$version from source gives a different app"
  pass "rebuilding the source gives exactly the same app"
fi

echo
echo "Reelmark $version verified."
