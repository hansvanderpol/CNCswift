# Validation evidence — 001-stl-to-gcode

**Feature**: `001-stl-to-gcode` | **Recorded**: 2026-11-20 | **Tasks**: T113, T114, T120–T124

This record maps the ten quickstart scenarios (VS-1 … VS-10) and the two human-verification
success criteria (SC-006, SC-009) to executed evidence. Automated results come from `Scripts/ci.sh`
and the named package suites; desktop-only observations are marked pending rather than inferred.
`checklists/requirements.md` checkbox markers were left untouched as a read-only gate.

## Scenario results

| Scenario | Evidence | Result |
|---|---|---|
| VS-1 — STL to `.nc` happy path | `CNCGCode` golden/header/emitter tests, `CNCPipeline` pipeline and commit-gate tests, `CNCValidation` rule tests, `generatedProgramFromAReferenceFixturePassesValidation` (T119, T120), `Packages/CNCPipeline/Tests/GenerationGoldenTests.swift` (T121) | **PASS (automated)** — see resolution below; GUI file-picker walkthrough is a desktop step |
| VS-2 — determinism | `Packages/CNCGCode/Tests/DeterminismTests.swift` | PASS (automated) |
| VS-3 — rejection, not repair | `CNCSTL` decode tests, `CNCToolpath` preflight tests, `CNCMaterials` preset/resolution tests | PASS (automated) |
| VS-4 — start/stop block integrity | `CNCValidation` parser and rule tests | PASS (automated) |
| VS-5 — 3D preview | `CNCSimulation/Tests/PreviewPerformanceTests.swift`; timings in `performance-evidence.md` | PASS (automated timing, 5/5); visual inspection pending |
| VS-6 — cutter edit propagates | `CNCPipeline/Tests/GenerationContractTests.swift`, `DeletionContractTests.swift` | PASS (automated) |
| VS-7 — library survives upgrade | `CNCCuttersStore/Tests/MigrationTests.swift`, `CNCMaterialsStore/Tests/MaterialStoreTests.swift` | PASS (automated) |
| VS-8 — offline and cancellable | `CNCDiagnostics`/`CNCPipeline` cancellation tests; `Scripts/offline-audit.sh`; launch-time network sample in `offline-audit.md` | PARTIAL — automated portions PASS; full-session network sample pending |
| VS-9 — material band has no overlap | `CNCMaterials/Tests/ResolutionTests.swift`, `MainScreenUI` blocked-state tests | PASS (automated) |
| VS-10 — feature smaller than cutter | `CNCToolpath/Tests/FeatureTests.swift` | PASS (automated) |

## VS-1 blocker found and resolved (T119)

Generating from a real reference STL placed the cutter-radius footprint at negative X/Y
(`G0 X-3.000 Y-3.000`), which validation rejected as an envelope violation (2,715 findings on the
200k fixture). The committed golden files start at `X10.000 Y10.000`, so the component tests did not
exercise that path. Details and timings are in `performance-evidence.md`.

T119 corrected `spindle-before-origin` to inspect the final origin return rather than the first
raster rapid through X0 Y0. T120 replaces its provisional clip with an explicit placement: the
model sits one cutter radius inside the stock's front-left corner and the swept centre region is
expanded by exactly one radius. `Preflight.check` and `checkPlanningInputs` now reject a job whose
expanded bounds would leave the stock or the machine envelope with
`PlanningError.insufficientCutterMargin`, whose message names the required 3.000 mm margin;
`Footprint.make` never clamps. Regression tests cover a rejected origin-placed model, an accepted
margin-placed model, a program generated from `relief-demo-binary.stl`, and raster rapids through
the origin. The SC-001 benchmark reports `findings=0` and the generated program has no validation
errors. T121–T124 add the reviewed pipeline-level golden fixture. The GUI file-picker walkthrough
still needs a desktop observation; the automated VS-1 path is unblocked.

## Pipeline-level golden review (T121–T124, C1)

`Fixtures/gcode/generation/footprint-margin-relief-demo-binary.nc` is the reviewed golden output of
the full decode → place → plan → emit path from the unchanged `relief-demo-binary.stl`. It closes C1
from `/speckit.analyze`: the existing five goldens are emitter-level and could not catch VS-1.

- **Test**: `committedGenerationGoldenMatchesPipelineOutput` in
  `Packages/CNCPipeline/Tests/GenerationGoldenTests.swift` asserts byte equality, zero validator
  findings, no errors, and non-negative in-stock X/Y for every move.
- **Review**: 1,715 ASCII lines, maximum line length 46 (limit 80), fixed `1970-01-01T00:00:00Z`
  header, profile start/stop blocks with `M30` last, X/Y 0–106.000 inside a 108 mm stock. Full
  fixed-input list and SHA-256 are recorded in `Fixtures/gcode/README.md`.
- **Update path**: `Scripts/update-golden.sh` emits a candidate only to gitignored
  `Fixtures/gcode/.received/` and prints `diff -u`; no test or script overwrites the committed
  fixture. `Scripts/ci.sh` rejects a modified tracked golden or a tracked `.received/` candidate.
- **Input integrity**: `git diff --exit-code -- Fixtures/stl/relief-demo-binary.stl` succeeds; the
  reference STL was not edited.

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

## Re-verification (2026-11-20)

`Scripts/ci.sh` re-run on 2026-11-20: exit 0 — format lint, DocC gate (99 files), offline audit,
workspace build, all 16 package suites green, golden fixture guard clean. SC-001 benchmark:
`triangles=200000 moves=3598 bytes=51551 decode=0.265s generation=0.053s validate=0.028s
total=0.346s findings=0`. SC-012 preview benchmark: five of five reference models each ≤ 0.006 s.
Automated SC-006 (`EmptyLibraryTests`) and SC-009 (`MainScreenUI`/`CutterLibraryModalUI`
accessibility suites) evidence is current.

## Manual verification owed (2026-11-20)

These steps cannot be driven from a non-interactive shell. T113 remains open until they are observed
on the desktop and the results are recorded here. `checklists/requirements.md` markers stay
untouched as a read-only gate.

| # | Criterion | Desktop step | Record |
|---|-----------|--------------|--------|
| M1 | SC-006 | From an absent cutter library, launch the app, add the first cutter, choose a reference STL, and reach a validated `.nc` **without help**. Time the full GUI flow; the target is under five seconds for entry as measured by `EmptyLibraryTests`. | elapsed time, pass/fail |
| M2 | SC-009 | With VoiceOver on, Tab through load STL → confirm units → confirm feed/spindle → confirm job values → acknowledge findings → write file. Every control must be reachable and announce a meaningful label/value; no pointing device. | pass/fail + any unlabeled control |
| M3 | SC-009 | Repeat for the cutter library: open with ⇧⌘L, add a valid cutter, edit it, save, close. | pass/fail |
| M4 | SC-009 | Repeat M2 and M3 with Full Keyboard Access on **and** off, Increase Contrast on, and Reduce Motion on. Confirm focus indicators stay visible and no animation plays under Reduce Motion. | pass/fail per setting |

Detail and result columns are in `accessibility-audit.md`.

## Re-run command

```bash
Scripts/ci.sh
```
