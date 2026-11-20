#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# FR-074 / SC-010: every bit of user data stays on this Mac. Fail the build if any shipping source
# or package manifest introduces a networking import, URL-loading API, socket, or telemetry hook.
# Test sources are excluded: a guard test may legitimately name a forbidden API to assert its absence.
echo "==> Offline audit (FR-074, SC-010)"

FORBIDDEN_PATTERNS=(
    'import Network'
    'import CFNetwork'
    'import FoundationNetworking'
    'import URLSession'
    'URLSession'
    'URLRequest'
    'NSURLSession'
    'NWConnection'
    'NWListener'
    'NWPathMonitor'
    'CFStreamCreatePair'
    'socket('
    'connect(to:'
    'telemetry'
    'analytics'
)

FORBIDDEN_DEPENDENCIES=(
    'Alamofire'
    'URLSession'
    'Starscream'
    'SwiftyJSON'
)

findings=0

audit_file() {
    local file="$1"
    for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
        if grep -nF -- "$pattern" "$file" >/dev/null 2>&1; then
            echo "OFFLINE VIOLATION: $file contains '$pattern'" >&2
            grep -nF -- "$pattern" "$file" >&2
            findings=$((findings + 1))
        fi
    done
}

# Shipping Swift sources only (exclude .build and test targets).
while IFS= read -r -d '' file; do
    audit_file "$file"
done < <(
    find App/Sources Packages \
        -type d -name .build -prune -o \
        -type d -name Tests -prune -o \
        -type f -name '*.swift' -print0
)

# Package manifests: no third-party networking dependency may be introduced.
while IFS= read -r -d '' manifest; do
    audit_file "$manifest"
    for dependency in "${FORBIDDEN_DEPENDENCIES[@]}"; do
        if grep -nF -- "$dependency" "$manifest" >/dev/null 2>&1; then
            echo "OFFLINE VIOLATION: $manifest declares '$dependency'" >&2
            findings=$((findings + 1))
        fi
    done
done < <(find . -path './.build' -prune -o -type f -name 'Package.swift' -print0)

if [[ "$findings" -ne 0 ]]; then
    echo "Offline audit failed with $findings finding(s)." >&2
    exit 1
fi

echo "Offline audit passed: no networking import, API, socket, or telemetry reference in shipping sources."
