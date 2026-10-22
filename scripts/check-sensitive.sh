#!/bin/bash
# Fails if a pull request changes security-sensitive files without the
# maintainer's review (the "maintainer-reviewed" label).
#
# Sensitive files are those that define what the app is allowed to do, what
# it sends over the network, where it keeps the TMDB token, how it is built
# and released, or how AI sessions are instructed.
# Usage: scripts/check-sensitive.sh <base> <head> <comma-separated labels>
set -euo pipefail

base="${1:?usage: check-sensitive.sh <base> <head> <labels>}"
head="${2:?usage: check-sensitive.sh <base> <head> <labels>}"
labels="${3:-}"

sensitive='^(Config/|\.github/|scripts/|Reelmark\.xcodeproj/|Reelmark/Resources/|Reelmark/Keychain\.swift$|Packages/ReelmarkCore/Package\.swift$|Packages/ReelmarkCore/Sources/ReelmarkCore/TMDBClient\.swift$|\.xcode-version$|CLAUDE\.md$)'

changed=$(git diff --name-only "$base...$head" | grep -E "$sensitive" || true)
if [ -z "$changed" ]; then
  echo "No sensitive files changed."
  exit 0
fi

echo "Sensitive files changed:"
echo "$changed" | sed 's/^/  /'
if [[ ",$labels," == *",maintainer-reviewed,"* ]]; then
  echo "The maintainer has reviewed this version (label: maintainer-reviewed)."
  exit 0
fi
echo "$changed" | head -n 20 | while IFS= read -r f; do
  echo "::error file=$f::Sensitive file changed. The maintainer must review it and add the 'maintainer-reviewed' label."
done
exit 1
