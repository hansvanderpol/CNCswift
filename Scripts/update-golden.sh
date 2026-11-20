#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

PLUGIN="$(xcode-select -p)/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
if [[ ! -f "$PLUGIN" ]]; then
    echo "Swift Testing macro plugin not found: $PLUGIN" >&2
    exit 1
fi

GOLDEN="Fixtures/gcode/generation/footprint-margin-relief-demo-binary.nc"
RECEIVED_DIR="Fixtures/gcode/.received"
CANDIDATE="$RECEIVED_DIR/$(basename "$GOLDEN")"

mkdir -p "$RECEIVED_DIR"
CNCSWIFT_GOLDEN_CANDIDATE_DIR="$PWD/$RECEIVED_DIR" \
    swift test --package-path Packages/CNCPipeline \
        -Xswiftc -load-plugin-library -Xswiftc "$PLUGIN" \
        --filter generateGoldenCandidateIntoReceivedDirectoryForReview

if [[ ! -f "$CANDIDATE" ]]; then
    echo "Golden candidate was not generated: $CANDIDATE" >&2
    exit 1
fi

echo "==> Review diff (committed -> candidate)"
diff -u "$GOLDEN" "$CANDIDATE" || true
echo "Review the candidate as production output, then promote by hand:"
echo "  cp $CANDIDATE $GOLDEN"
