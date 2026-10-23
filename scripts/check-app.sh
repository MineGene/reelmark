#!/bin/bash
# Checks a built Reelmark.app: architecture, signature, entitlements and the
# web addresses inside it. Fails if the app could do more than it says:
#   - it must be sandboxed, with exactly the entitlements listed below
#   - its only web address must be The Movie Database's
# Usage: scripts/check-app.sh path/to/Reelmark.app
set -euo pipefail

app="${1:?usage: check-app.sh path/to/Reelmark.app}"
binary="$app/Contents/MacOS/Reelmark"
fail() { echo "::error::$*"; exit 1; }

[ -d "$app" ] || fail "App not found at $app"

echo "== Architecture"
archs=$(lipo -archs "$binary")
echo "$binary: $archs"
[ "$archs" = "arm64" ] || fail "Reelmark should be Apple silicon only, found: $archs"

echo "== Bundled code"
# Apple frameworks only: nothing may be embedded besides the app itself.
extra=$(find "$app/Contents" \( -name "*.framework" -o -name "*.dylib" -o -name "*.xpc" -o -name "*.appex" -o -name "*.bundle" \) -print)
[ -z "$extra" ] || fail "Unexpected embedded code: $extra"
echo "None"

echo "== Icon"
# The Icon Composer icon (Reelmark/AppIcon.icon) compiles into Assets.car;
# without it Finder and the Dock show a blank icon.
icon=$(plutil -extract CFBundleIconName raw "$app/Contents/Info.plist" 2>/dev/null || true)
[ -n "$icon" ] && [ -f "$app/Contents/Resources/Assets.car" ] || fail "The app has no icon"
echo "$icon"

echo "== Signature"
codesign --verify --deep --strict --verbose=2 "$app"
# Capture first: piping into "grep -q" lets grep exit early, codesign then
# dies writing to the closed pipe, and pipefail reports a false failure.
signature=$(codesign -d --verbose=2 "$app" 2>&1)
grep -q "flags=.*runtime" <<<"$signature" || fail "Hardened runtime is not enabled"

echo "== Entitlements"
# Exactly these, nothing more. Changing this list is a sensitive change.
allowed="com.apple.security.app-sandbox
com.apple.security.files.bookmarks.app-scope
com.apple.security.files.user-selected.read-write
com.apple.security.network.client"
ents=$(codesign -d --entitlements - --xml "$app" 2>/dev/null)
echo "$ents" | plutil -p - || true
actual=$(echo "$ents" | grep -oE '<key>[^<]+</key>' | sed -E 's#</?key>##g' | LC_ALL=C sort)
if [ "$actual" != "$allowed" ]; then
  echo "Expected:"; echo "$allowed"; echo "Found:"; echo "$actual"
  fail "Entitlements differ from the allowed list"
fi

echo "== Web addresses in the app"
# The app talks only to TMDB's API; the website link in Settings is shown
# for the user to open in their own browser.
hosts=$(strings -a "$binary" | grep -oE 'https?://[A-Za-z0-9.-]+' | sed -E 's#https?://##' | LC_ALL=C sort -u)
echo "${hosts:-none}"
for host in $hosts; do
  case "$host" in
    api.themoviedb.org | www.themoviedb.org) ;;
    *) fail "Unexpected web address in the app: $host" ;;
  esac
done
grep -qE 'http://' <(strings -a "$binary") && fail "The app contains an unencrypted http:// address"

echo "All checks passed."
