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

## Re-verification (2026-11-20)

`Scripts/make-app.sh` re-run and signing re-checked on 2026-11-20: identifier
`com.hansvanderpol.CNCswift`, `Signature=adhoc`, thin arm64, no TeamIdentifier, and exactly the two
required entitlements (`com.apple.security.app-sandbox=true`,
`com.apple.security.files.user-selected.read-write=true`). The automatable portion of T115 is
current.

## Still owed (desktop-only) — T115

The security-scoped file-picker grant cannot be driven from a non-interactive shell. T115 stays open
until this checklist is observed on the desktop and the results are recorded below.

| # | Desktop step | Expected | Result (fill on desktop) |
|---|--------------|----------|--------------------------|
| 1 | `open .build/CNCswift.app` and confirm the window appears. | Process launches, stays alive, no crash report. | pending |
| 2 | Use the app's file picker to open a user-selected STL outside the app container (for example `Fixtures/stl/relief-demo-binary.stl`). | The security-scoped read grant is honored; the model loads. | pending |
| 3 | Generate and commit a `.nc` to a user-selected output directory through the same picker. | The security-scoped write grant is honored; exactly one `.nc` is written. | pending |
| 4 | Quit and relaunch, then reopen the same STL. | Access is re-granted on a fresh user selection; no entitlement was dropped. | pending |

The entitlement is present in the signed bundle and the app has already launched with it, so no
signing change is expected from these checks.

## Re-verification (2026-11-21)

`Scripts/make-app.sh` re-run, then `codesign -dvv .build/CNCswift.app` and
`codesign -d --entitlements :- .build/CNCswift.app`:

| Check | Observed | Result |
|---|---|---|
| Identifier | `com.hansvanderpol.CNCswift` | PASS |
| Signature | `adhoc` | PASS |
| Format | app bundle, Mach-O thin arm64 | PASS |
| TeamIdentifier | not set | PASS (no Developer ID) |
| Entitlements | exactly `com.apple.security.app-sandbox=true` and `com.apple.security.files.user-selected.read-write=true` | PASS |

`open .build/CNCswift.app` started PID 29210, alive after three seconds, and `lsof -nP -i -a -p`
returned no rows; the process was terminated after the observation. No entitlement was dropped.

The four security-scoped picker steps above remain pending. An `osascript` System Events probe on
2026-11-21 returned `osascript is not allowed assistive access (-1728)`, so the file-picker grant
cannot be exercised from this non-interactive shell. T115 stays open until those steps are
observed on the desktop.
