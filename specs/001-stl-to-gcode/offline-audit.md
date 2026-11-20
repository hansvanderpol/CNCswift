# Offline audit record — 001-stl-to-gcode

**Feature**: `001-stl-to-gcode` | **Last run**: 2026-11-20 11:20 CET

This file records the evidence for FR-074 and SC-010. It is a record only; the executable gate is
`Scripts/offline-audit.sh`, invoked by `Scripts/ci.sh`.

## Automated static audit (FR-074)

Gate: `bash Scripts/offline-audit.sh`, run automatically from `Scripts/ci.sh` before build/test.

Method: scans shipping Swift sources under `App/Sources` and `Packages/*/Sources` (excluding
`.build` and test targets) plus every `Package.swift` for networking imports (`Network`,
`CFNetwork`, `FoundationNetworking`), URL-loading APIs (`URLSession`, `URLRequest`,
`NSURLSession`), network framework types (`NWConnection`, `NWListener`, `NWPathMonitor`), sockets,
and telemetry/analytics hooks. Any finding fails the build. Test sources are excluded so a guard
test may name a forbidden API in order to assert its absence.

Negative check: a probe source containing `import Network` and `URLSession.shared` made the audit
exit non-zero with two findings; the probe was removed and the audit returned to green.

| Run | Result |
|---|---|
| 2026-11-20 | PASS — no networking import, API, socket, or telemetry reference in shipping sources |

## Observed network monitor — launch and idle (partial SC-010)

Method: built the ad-hoc signed bundle with `Scripts/make-app.sh`, launched it with
`open .build/CNCswift.app`, and sampled the running process twice about three seconds apart.

| Sample | Command | Result |
|---|---|---|
| 1 | `lsof -nP -i -a -p <pid>` | no rows — zero outbound connections |
| 2 | `lsof -nP -i -a -p <pid>` | no rows — zero outbound connections |
| 3 | `lsof -nP -iTCP -sTCP:LISTEN -a -p <pid>` | no rows — no listening sockets |

The process was then terminated normally. This covers launch and idle only.

## Full-session observation (VS-8 / SC-010) — pending human verification

SC-010 requires observation across a complete session (launch → load STL → generate → review
preview → commit). That interaction cannot be driven from this non-interactive shell, so it remains
a desktop step. To complete it:

```bash
cd /Users/hans/projects/CNCswift
Scripts/make-app.sh
open .build/CNCswift.app
PID=$(pgrep -f 'CNCswift.app/Contents/MacOS/CNCswift' | head -1)
lsof -nP -i -a -p "$PID"        # sample throughout the session
```

Expected: no outbound connections at any point; generation is cancellable; a cancelled job leaves
no `.nc` or temporary file. Record the observed result here when performed.

## Related launch fix

The first launch attempt aborted with
`Fatal error: unable to find bundle named CNCMachineProfile_CNCMachineProfile`. `Scripts/make-app.sh`
copied only the executable and `Info.plist`, omitting SwiftPM's generated resource bundle. The
script now copies all `*.bundle` products into `Contents/Resources`; the relaunch succeeded, which
made the observation above possible.
