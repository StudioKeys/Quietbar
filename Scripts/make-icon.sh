#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

swiftc -O "$root/Scripts/MakeIcon.swift" -o "$work/make-icon"
"$work/make-icon" "$work/AppIcon.iconset"
iconutil --convert icns "$work/AppIcon.iconset" --output "$root/Resources/AppIcon.icns"
cp "$work/AppIcon.iconset/icon_256x256@2x.png" "$root/docs/images/icon.png"

echo "Wrote $root/Resources/AppIcon.icns"
