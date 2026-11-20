# Bundle verification — 001-stl-to-gcode

**Feature**: `001-stl-to-gcode` | **Recorded**: 2026-11-20 | **Task**: T115 (FR-073, FR-075, FR-076)

Commands run from the repository root after `Scripts/make-app.sh`:

```bash
codesign -dvv .build/CNCswift.app
codesign -d --entitlements :- .build/CNCswift.app
open .build/CNCswift.app
lsof -nP -i -a -p "$(pgrep -f 'CNCswift.app/Contents/MacOS/CNCswift' | head -1)"
```

## Signature and identifier

| Check | Observed | Result |
|---|---|---|
| `Identifier` | `com.hansvanderpol.CNCswift` | PASS |
| `Signature` | `adhoc` (flags `0x2(adhoc)`) | PASS |
| `Format` | app bundle, Mach-O thin arm64 | PASS |
| `TeamIdentifier` | not set | PASS (no Developer ID) |
| `Sealed Resources` | version 2, 13 rules, 6 files | PASS |
| `Total signatures` | 1 | PASS |

## Entitlements

The signed bundle carries exactly two entitlements:

| Entitlement | Value | Result |
|---|---|---|
| `com.apple.security.app-sandbox` | `true` | PASS |
| `com.apple.security.files.user-selected.read-write` | `true` | PASS |

No hardware, USB, serial, network, or other file-access entitlement is present. The sandbox
entitlement was not dropped to work around signing.

## Launch

`open .build/CNCswift.app` started the process
(`/Users/hans/projects/CNCswift/.build/CNCswift.app/Contents/MacOS/CNCswift`, observed PID 95940)
and it remained alive after three seconds. No new diagnostic report was generated for that launch;
the three reports dated 11:19 predate the resource-bundle fix recorded in `offline-audit.md`.
`lsof -nP -i` for the running process returned no rows.

The process was terminated after the observation.

## Still owed (desktop-only)

Opening a user-selected STL through the sandbox's file picker and confirming the security-scoped
read/write grant cannot be driven from a non-interactive shell. That step remains a human check;
the entitlement itself is present in the signed bundle and the app has already launched with it.
