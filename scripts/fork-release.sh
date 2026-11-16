#!/bin/bash
# Publishes a fork build for Homebrew: a Release build signed with a local identity and no Sparkle
# feed, zipped onto a GitHub release of the fork, and the tap's Casks/uvim-fork.rb pointed at it.
# No Apple notarization: the cask clears the quarantine flag instead.
# Usage: scripts/fork-release.sh VERSION SIGN_IDENTITY   (e.g. 1.1.2-fork.1 ED91A5BF…)
# Env: FORK (default altsang/uvim), TAP (default altsang/homebrew-tap).
set -euo pipefail
version=${1:?usage: fork-release.sh VERSION SIGN_IDENTITY}
identity=${2:?usage: fork-release.sh VERSION SIGN_IDENTITY}
fork=${FORK:-altsang/uvim}
tap=${TAP:-altsang/homebrew-tap}
root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$root"

[ -z "$(git status --porcelain)" ] || { echo "commit your changes first" >&2; exit 1; }
xcodegen generate >/dev/null
xcodebuild -project uvim.xcodeproj -scheme uvim -configuration Release -derivedDataPath "$work/build" \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$identity" DEVELOPMENT_TEAM= ENABLE_HARDENED_RUNTIME=NO \
    OTHER_CODE_SIGN_FLAGS= SPARKLE_FEED_URL= SPARKLE_PUBLIC_KEY= \
    CURRENT_PROJECT_VERSION="$(git rev-list --count HEAD)" build -quiet
app="$work/build/Build/Products/Release/uvim.app"
codesign --verify --deep --strict "$app"
feed=$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$app/Contents/Info.plist" 2>/dev/null || true)
[ -z "$feed" ] || { echo "the build still names a Sparkle feed: $feed" >&2; exit 1; }

zip="$work/uvim-$version.zip"
ditto -c -k --keepParent "$app" "$zip"
sum=$(shasum -a 256 "$zip" | cut -d' ' -f1)

git tag -f "v$version"
git push -f "https://github.com/$fork.git" "v$version"
gh release create "v$version" "$zip" --repo "$fork" --title "uvim $version" \
    --notes "Fork build for Homebrew: \`brew install --cask altsang/tap/uvim-fork\`. Not notarized." --verify-tag

cask=$(<scripts/fork-cask.rb)
cask=${cask//@VERSION@/$version}
cask=${cask//@SHA256@/$sum}
current=$(gh api "repos/$tap/contents/Casks/uvim-fork.rb" --jq .sha 2>/dev/null || true)
gh api -X PUT "repos/$tap/contents/Casks/uvim-fork.rb" -f message="uvim-fork $version" \
    -f content="$(printf '%s\n' "$cask" | base64)" ${current:+-f sha="$current"} >/dev/null
echo "Published uvim-fork $version ($sum)"
