#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

PLUGIN="$(xcode-select -p)/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
if [[ ! -f "$PLUGIN" ]]; then
    echo "Swift Testing macro plugin not found: $PLUGIN" >&2
    exit 1
fi

echo "==> Format lint"
swift format lint --configuration .swift-format --recursive Package.swift App Packages

echo "==> Offline audit"
bash Scripts/offline-audit.sh

echo "==> Build"
swift build

echo "==> Test"
# SwiftPM runs the root package's tests only; each local package owns a test target.
for package in Packages/*; do
    echo "--- $package"
    swift test --package-path "$package" \
        -Xswiftc -load-plugin-library -Xswiftc "$PLUGIN"
done
