# Validation evidence — 001-stl-to-gcode

**Feature**: `001-stl-to-gcode` | **Recorded**: 2026-11-20 | **Tasks**: T113, T114

This record maps the ten quickstart scenarios (VS-1 … VS-10) and the two human-verification
success criteria (SC-006, SC-009) to executed evidence. Automated results come from `Scripts/ci.sh`
and the named package suites; desktop-only observations are marked pending rather than inferred.
`checklists/requirements.md` checkbox markers were left untouched as a read-only gate.

## Scenario results

| Scenario | Evidence | Result |
|---|---|---|
| VS-1 — STL to `.nc` happy path | `CNCGCode` golden/header/emitter tests, `CNCPipeline` pipeline and commit-gate tests, `CNCValidation` rule tests | **BLOCKED end to end** — see finding below; all component tests pass |
| VS-2 — determinism | `Packages/CNCGCode/Tests/DeterminismTests.swift` | PASS (automated) |
| VS-3 — rejection, not repair | `CNCSTL` decode tests, `CNCToolpath` preflight tests, `CNCMaterials` preset/resolution tests | PASS (automated) |
| VS-4 — start/stop block integrity | `CNCValidation` parser and rule tests | PASS (automated) |
| VS-5 — 3D preview | `CNCSimulation/Tests/PreviewPerformanceTests.swift`; timings in `performance-evidence.md` | PASS (automated timing, 5/5); visual inspection pending |
| VS-6 — cutter edit propagates | `CNCPipeline/Tests/GenerationContractTests.swift`, `DeletionContractTests.swift` | PASS (automated) |
| VS-7 — library survives upgrade | `CNCCuttersStore/Tests/MigrationTests.swift`, `CNCMaterialsStore/Tests/MaterialStoreTests.swift` | PASS (automated) |
| VS-8 — offline and cancellable | `CNCDiagnostics`/`CNCPipeline` cancellation tests; `Scripts/offline-audit.sh`; launch-time network sample in `offline-audit.md` | PARTIAL — automated portions PASS; full-session network sample pending |
| VS-9 — material band has no overlap | `CNCMaterials/Tests/ResolutionTests.swift`, `MainScreenUI` blocked-state tests | PASS (automated) |
| VS-10 — feature smaller than cutter | `CNCToolpath/Tests/FeatureTests.swift` | PASS (automated) |

## VS-1 blocker found during this wave

Generating from a real reference STL places the cutter-radius footprint at negative X/Y
(`G0 X-3.000 Y-3.000`), which validation rejects as an envelope violation (2,715 findings on the
200k fixture). The committed golden files start at `X10.000 Y10.000`, so the component tests do not
exercise this path. Details and timings are in `performance-evidence.md`.

VS-1 therefore cannot be recorded as an end-to-end pass until either the job placement is corrected
by the planner/preflight or the operator places the model inside the stock with at least one cutter
radius of margin. This is a follow-up task, not a silently accepted regression.

## SC-006 — timed empty-library first file (T113)

`Packages/CutterLibraryModalUI/Tests/EmptyLibraryTests.swift` starts from an absent library,
asserts that every required field reports what to enter, completes the first valid cutter entry in
under five seconds, persists it, and repeats the path for a second cutter. **PASS (automated)**.

The human-timed empty-library → first `.nc` walkthrough from quickstart is still owed; the
automated test measures entry and storage, not the full GUI flow.

## SC-009 — keyboard-only and accessibility settings (T113)

`Packages/MainScreenUI/Tests/AccessibilityTests.swift` and
`Packages/CutterLibraryModalUI/Tests/AccessibilityTests.swift` verify announcement text, labels and
values for every generation state and cutter row. `App/Sources/CNCswiftApp/Accessibility.swift`
applies Reduce Motion, Increase Contrast, VoiceOver announcements, and Full Keyboard Access
behaviour; menu shortcuts call the same model methods as the controls. **PASS (automated)**.

The desktop walkthroughs in `accessibility-audit.md` — VoiceOver tab order through both workflows,
Full Keyboard Access on/off, Increase Contrast and Reduce Motion — remain human verification and
are recorded as pending there, not claimed here.

## Re-run command

```bash
Scripts/ci.sh
```
