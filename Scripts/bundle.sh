#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/.build/Quietbar.app"

swift build --package-path "$root" -c release --product Quietbar
binary="$(swift build --package-path "$root" -c release --show-bin-path)/Quietbar"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$binary" "$app/Contents/MacOS/Quietbar"
cp "$root/Resources/Info.plist" "$app/Contents/Info.plist"
codesign --force --sign - --options runtime "$app"
codesign --verify --strict "$app"

echo "Built $app"
