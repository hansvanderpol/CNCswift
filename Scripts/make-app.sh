#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIGURATION="${CONFIGURATION:-debug}"
EXECUTABLE=".build/$CONFIGURATION/CNCswiftApp"
BUNDLE=".build/CNCswift.app"
ENTITLEMENTS="App/Resources/CNCswift.entitlements"

if [[ ! -x "$EXECUTABLE" ]]; then
    echo "Built executable not found: $EXECUTABLE (run 'swift build' first)" >&2
    exit 1
fi

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$EXECUTABLE" "$BUNDLE/Contents/MacOS/CNCswift"
cp App/Resources/Info.plist "$BUNDLE/Contents/Info.plist"

/usr/bin/codesign --sign - --force \
    --entitlements "$ENTITLEMENTS" \
    "$BUNDLE"

echo "Created ad-hoc signed bundle: $BUNDLE"
