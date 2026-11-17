#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/.build/Quietbar.app"

swift build --package-path "$root" -c release --product Quietbar
binary="$(swift build --package-path "$root" -c release --show-bin-path)/Quietbar"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary" "$app/Contents/MacOS/Quietbar"
cp "$root/Resources/Info.plist" "$app/Contents/Info.plist"
cp "$root/Resources/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
codesign --force --sign "${QUIETBAR_SIGN_IDENTITY:--}" --options runtime "$app"
codesign --verify --strict "$app"

echo "Built $app"
