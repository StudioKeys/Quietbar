#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
minimum="${COVERAGE_MINIMUM:-80}"

swift test --package-path "$root" --enable-code-coverage >/dev/null
profile="$(swift test --package-path "$root" --show-codecov-path)"
profdata="$(dirname "$profile")/default.profdata"
products="$(swift build --package-path "$root" --show-bin-path)"
objects=()
for target in "$root"/Tests/*/; do
    name="$(basename "$target")"
    objects+=(-object "$products/$name.xctest/Contents/MacOS/$name")
done

report="$(xcrun llvm-cov report "${objects[@]}" -instr-profile "$profdata" \
    -ignore-filename-regex '(Tests/|\.build/|Sources/BluetoothLE/|Sources/Quietbar/(Views|App)/)')"
echo "$report"

total="$(echo "$report" | awk '/^TOTAL/ {print $10}' | tr -d '%')"
echo "Line coverage: ${total}% (minimum ${minimum}%)"
awk -v total="$total" -v minimum="$minimum" 'BEGIN { exit (total + 0 >= minimum + 0) ? 0 : 1 }'
