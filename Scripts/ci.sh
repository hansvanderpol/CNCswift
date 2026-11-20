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

echo "==> DocC gate"
python3 Scripts/check-docc.py

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

echo "==> Golden fixture guard"
# Tests never write committed goldens. A dirty tracked golden or a tracked review candidate means
# the fixture was changed without the production-output review required by the Development Workflow.
git diff --exit-code -- ':(glob)Fixtures/gcode/*.nc' ':(glob)Fixtures/gcode/**/*.nc'
if git ls-files Fixtures/gcode | grep -Eq '(^|/)\.received/'; then
    echo "Golden review candidates under Fixtures/gcode/.received/ must not be tracked" >&2
    exit 1
fi
