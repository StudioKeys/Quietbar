#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/.build/Quietbar.app"
zip="$root/.build/Quietbar.zip"

"$root/Scripts/bundle.sh"
rm -f "$zip"
ditto -c -k --norsrc --noextattr --noacl --keepParent "$app" "$zip"

echo "Packaged $zip"
