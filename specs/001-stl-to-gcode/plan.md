# Implementation Plan: STL to Machine-Ready G-code

**Branch**: `001-stl-to-gcode` | **Date**: 2026-11-17 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-stl-to-gcode/spec.md` (81 functional requirements, 13 success criteria, three clarification answers recorded on 2026-11-17).

## Summary

Build CNCswift as a thin SwiftUI macOS shell over local Swift packages that turn an STL mesh into validated GRBL 1.1 G-code for a TwoTrees TTC450 PRO. The pipeline is five typed stages — decode, toolpath generation (roughing then raster finishing), post-processing, independent validation, and simulation — plus a versioned cutter library, a material library with recommended cutting bands, a 3D material-removal preview, and an emitter that writes one deterministic `.nc` file bounded by the profile's fixed start and stop blocks.

Two clarified behaviours shape the design:

1. **Material decides the starting load.** A named material carries a recommended feed band and spindle band. The effective value for a job is chosen inside the intersection of that band and the profile's limits, prefilled from the cutter record, and explicitly confirmed per job (FR-077 – FR-081). Material resolution therefore needs one owner, not scattered conditionals across the planner, emitter, and UI.
2. **Rapids are machine setup, not program text.** GRBL's `G0` ignores any `F` word, so no emitted line can carry a rapid rate. The 800 mm/min rapid ceiling is met by the controller's rapid-rate settings (`$110`–`$112`), confirmed before generation, and the program never claims otherwise (FR-024). This mirrors the constitution's existing `$30`/`$31` spindle-buffer precedent.

The approach stays profile-driven: every dialect token, limit, and block comes from one versioned machine description, so the pipeline contains no GRBL literals and a second machine would be new data rather than a new code path.

This revision also resolves three CRITICAL findings from `/speckit.analyze` in the design rather than in the task list:

- **C1** — orchestration moves out of `CNCToolpath` into a new `CNCPipeline` package, so the planner never imports the emitter or the validator.
- **C2** — the atomic writer and its tests both live in `CNCGCode`, so `CNCValidation` keeps its structural independence from the emitter.
- **C3** — the "no hardware control" and "no laser output" prohibitions (FR-030, FR-031) become module-boundary guards with their own tests, not prose.

## Technical Context

**Language/Version**: Swift 6.4.2 toolchain, Swift 6 language mode, `-strict-concurrency=complete` with warnings as errors.

**Primary Dependencies**: Apple frameworks only — SwiftUI, RealityKit (3D preview), Foundation, `os.Logger`, UniformTypeIdentifiers. No third-party packages.

**Storage**: JSON documents in the app's sandboxed Application Support directory — the cutter library and the material library — each with a schema version, atomic replace, and forward-only migrations, over shared persistence primitives.

**Testing**: Swift Testing (`import Testing`) in a test target per package, driven by `swift test` with the macro-plugin flag (D2). Golden-file fixtures for G-code, STL fixtures in ASCII and binary, preset-band fixtures for the four built-in materials, and library fixtures for every schema version. A neutral integration target runs the library-to-generation contract test.

**Target Platform**: macOS 27.0 or later, arm64. Local build and run only; no distribution, signing identity, or notarisation.

**Project Type**: native macOS desktop application over a Swift package workspace.

**Performance Goals**: decode plus generation for a 200,000-triangle model completes in under 5 minutes; the 3D preview renders within 5 seconds of validation for 95% of reference models.

**Constraints**: GRBL 1.1 dialect only; 460 x 460 x 80 mm envelope; 800 mm/min feed ceiling; 800 mm/min rapid rate achieved through controller settings rather than program text; 5,000-8,000 RPM inclusive spindle range; `.nc` output only; **80-character maximum per G-code line** (GRBL's line buffer, error:11); byte-deterministic output apart from documented header fields; fully offline and sandboxed.

**Scale/Scope**: single-user desktop app; roughly sixteen small packages; one main screen with three panels and one modal; one machine profile; four built-in material presets plus user-defined materials.

### Verified toolchain facts

These were executed on this machine, not assumed:

| Check | Result |
|---|---|
| OS / arch | macOS 27.2.1, arm64 |
| Swift toolchain | 6.4.2 (`swift-driver 1.168.6`) |
| `xcodebuild` | **unavailable** — active developer dir is Command Line Tools, no Xcode |
| `swift format` | 6.4.4, available as `swift format` |
| `codesign` | `/usr/bin/codesign` present |
| SDK | `MacOSX27.2.sdk` with SwiftUI, RealityKit, SceneKit, Metal |
| Swift Testing | works, but requires an explicit plugin flag (research D2) |
| SwiftUI + RealityKit link | verified with `-parse-as-library -swift-version 6 -strict-concurrency=complete -target arm64-apple-macos27.0` |

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Gate | Status |
|---|---|---|
| I. Swift 6 Language Mode and Strict Concurrency | `swiftLanguageMode(.v6)` and complete concurrency checking in every `Package.swift`; warnings as errors; UI state `@MainActor`; pipeline in an actor | PASS |
| II. Modular Package-First Architecture | Domain, persistence, and IO in `Packages/`; app target is composition root only; one-way dependencies `presentation -> pipeline -> stages` | PASS — five new packages, each justified below |
| III. Test-First (NON-NEGOTIABLE) | Swift Testing target per package; failing test first; injected clock and injected file system so no test touches real time or the real Application Support directory | PASS — with the verified tooling workaround (D2) |
| IV. Native macOS Fidelity and Accessibility | SwiftUI default; keyboard-only operation; accessibility labels/roles/values; sandboxed with declared entitlements; no data leaves the machine | PASS |
| V. Observability, Diagnostics, and Error Discipline | `os.Logger` per module with stable categories; typed errors with correlation identifiers; progress and cancellation distinguished from failure; DocC on public API | PASS |
| VI. STL to Machine-Ready G-code | Decode, toolpath, post-process, validate as separate packages with typed boundaries; one versioned profile; no dialect literals in the pipeline; fixed start/stop blocks; 80-character line limit; envelope and limit rejection (never clamping); deterministic output | PASS — with one recorded interpretation for the rapid ceiling, below |
| VII. G-code Main Screen and Cutter Library Modal | Three-panel main screen; separate modal module; no shared mutable state; persisted library as the only contract; closed cutter enum with per-type dimensions; validated at entry; Application Support, atomic, versioned, forward-only migrations | PASS |

### Recorded interpretation: rapid ceiling (Principle VI)

Principle VI says an emitted rapid above 800 mm/min "MUST be rejected, never clamped". GRBL 1.1 ignores any `F` word on a `G0` line, so a rapid's rate cannot be expressed in the program and cannot be checked there. The clarified FR-024 resolves this the same way the constitution already resolves spindle buffers: the profile declares the required controller settings (`$110`, `$111`, `$112` = 800), the app documents them, the operator confirms them before generation, and generation is blocked until that confirmation is recorded. Validation rejects a feed word on any rapid line, which is the only program-side claim the file could make.

This is compliant in intent — no emitted move exceeds the ceiling, and no over-limit rapid is ever produced — but it is an interpretation, not a literal reading. **Recommended follow-up**: a PATCH amendment to Principle VI and the Technology Stack section stating that the rapid ceiling is a controller-setting requirement, phrased like the existing `$30`/`$31` paragraph. Until that amendment exists, this paragraph is the recorded finding required by the Governance section.

No other constitutional violations require justification. Two tooling deviations remain in Complexity Tracking because they constrain the build, not the design.

## Project Structure

### Documentation (this feature)

```text
specs/001-stl-to-gcode/
├── plan.md              # This file
├── research.md          # Phase 0 decisions and rejected alternatives
├── data-model.md        # Phase 1 entities, validation rules, state transitions
├── quickstart.md        # Phase 1 validation and run guide
├── contracts/
│   ├── machine-profile.md
│   ├── material-library.md
│   ├── cutter-library.md
│   ├── gcode-output.md
│   └── toolpath-api.md
├── checklists/
│   └── requirements.md
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
Package.swift                          # root package aggregating the workspace
Packages/
├── CNCMachineProfile/                 # profile value types + GRBL 1.1 profile data
├── CNCDiagnostics/                    # typed errors, correlation IDs, logging, progress, cancellation
├── CNCStorage/                        # atomic write, versioned documents, backup, migration runner
├── CNCGeometry/                       # Vec3, Mesh, AABB, BVH, ray casting, transform
├── CNCSTL/                            # ASCII and binary decode, manifold checks
├── CNCCutters/                        # cutter taxonomy, entry validation
├── CNCCuttersStore/                   # cutter library persistence over CNCStorage
├── CNCMaterials/                      # Material entity, four presets, band validation, effective-value resolution
├── CNCMaterialsStore/                 # user-defined material persistence over CNCStorage
├── CNCToolpath/                       # roughing layers + raster finishing planner, preflight
├── CNCGCode/                          # emitter, header, blocks, formatting, atomic file writer
├── CNCValidation/                     # independent GRBL 1.1 parser + rule checks
├── CNCSimulation/                     # z-map material removal, preview mesh
├── CNCPipeline/                       # ToolpathService actor orchestrating the stages
├── MainScreenUI/                      # three-panel screen and its view model
└── CutterLibraryModalUI/              # modal module and its view model

App/
└── Sources/CNCswiftApp/               # composition root, scenes, menus, entitlements

Scripts/
├── make-app.sh                        # assemble CNCswift.app from `swift build`
└── ci.sh                              # format lint + build + test

Fixtures/
├── stl/                               # ASCII and binary reference meshes
├── gcode/                             # golden files, reviewed as production output
├── library/                           # cutter schema v1 and v2 fixtures
└── materials/                         # preset band fixture, user-material fixture
```

### Package dependency graph

```text
CNCMachineProfile   CNCDiagnostics   CNCGeometry   CNCStorage
        |                  |               |            |
        +------------------+---------------+------------+
                           |
   CNCSTL <----------------+                CNCCutters <--- CNCMachineProfile
      |                                      |      |
      v                                      v      v
CNCGeometry                        CNCCuttersStore  CNCMaterials
                                             \        /
                                              v      v
CNCMaterialsStore --> CNCStorage          CNCToolpath --> CNCGeometry
                                                 |
                                                 v
                                              CNCGCode
                                                 |
              CNCValidation (String in) <--------+
                    |
                    v
               CNCSimulation

CNCPipeline -> CNCSTL, CNCToolpath, CNCGCode, CNCValidation, CNCSimulation,
               CNCCuttersStore, CNCMaterialsStore, CNCDiagnostics

MainScreenUI -> CNCPipeline + domain value types (read-only)
CutterLibraryModalUI -> CNCCutters, CNCCuttersStore
```

Hard rules, repeated from `contracts/toolpath-api.md` because they are architectural:

- `CNCValidation` takes program text as a `String` and never imports `CNCGCode`.
- `CNCToolpath` never imports `CNCGCode`, `CNCValidation`, or `CNCPipeline`.
- Orchestration lives only in `CNCPipeline`; no stage package depends on it.
- No domain package imports SwiftUI or RealityKit.
- `CNCMaterials` is the only place effective feed and spindle are resolved.

### Package rationale (Principle II)

| Package | Why it exists | Rejected alternative |
|---|---|---|
| `CNCDiagnostics` | Five packages need the same typed errors, correlation identifiers, logger categories, and cancellation helper | Duplicating error and logging code per package would diverge at the first fix |
| `CNCStorage` | Cutter and material libraries need identical atomic write, backup, schema stamp, and migration-runner behaviour | Letting each store reimplement it invites two subtly different durability contracts |
| `CNCMaterials` | One owner for Material, the four presets, band validation, and the effective-value intersection (FR-077 – FR-080) | Spreading band logic across planner, emitter, and UI makes FR-080 unprovable in one test |
| `CNCMaterialsStore` | FR-077 requires user-defined materials to persist across launches, with the same guarantees as cutters | Storing materials inside the cutter document couples two unrelated schemas and their migrations |
| `CNCPipeline` | Orchestrates decode → plan → render → validate → simulate → write in one actor; the only package allowed to know all stages | Putting it in `CNCToolpath` (the previous plan) forces the planner to import the emitter and validator, contradicting Principle VI's typed boundaries |

**Structure Decision**: One package per pipeline stage, two stores over one storage package, one orchestration package, and one package per presentation module. The app target holds only the composition root and scene wiring. The root `Package.swift` aggregates the workspace so `swift build` and `swift test` cover everything from the repository root.

## Design Flow

**Phase 0 output**: [research.md](./research.md) — fourteen decisions, each with rationale and rejected alternatives, including the Swift Testing plugin workaround, the RealityKit choice forced by SceneKit's deprecation, the material-band resolution rule, the rapid-rate enforcement rule, and the orchestration package boundary.

**Phase 1 outputs**:

- [data-model.md](./data-model.md) — entities, fields, validation rules, and state transitions, including `Material`, `EffectiveCuttingValues`, and the preset band table.
- [contracts/machine-profile.md](./contracts/machine-profile.md) — the versioned profile schema, the TTC450 PRO values, and the controller settings that are machine setup.
- [contracts/material-library.md](./contracts/material-library.md) — the four presets, band validation, resolution rules, and user-material storage.
- [contracts/cutter-library.md](./contracts/cutter-library.md) — cutter record schema, storage layout, migration contract, and the change-notification mechanism behind FR-060.
- [contracts/gcode-output.md](./contracts/gcode-output.md) — the emitted file format, header fields (including material and effective values), block order, and the 80-character line rule.
- [contracts/toolpath-api.md](./contracts/toolpath-api.md) — typed package boundaries between stages and the orchestration protocol.
- [quickstart.md](./quickstart.md) — build, test, run, and end-to-end validation scenarios.

## Post-Design Constitution Re-check

Re-evaluated after Phase 1 design. All seven principles still pass.

- **C1 resolved structurally**: `CNCPipeline` is the only package that imports all stages. `CNCToolpath` depends on geometry, cutters, materials, and the profile; it does not import `CNCGCode`, `CNCValidation`, or the pipeline. A build-graph test asserts the forbidden edges stay absent.
- **C2 resolved structurally**: `FileWriter` and its atomic-write tests both live in `CNCGCode`. `CNCValidation` still receives text and owns its own parser, so validation cannot inherit the emitter's assumptions.
- **C3 enforced, not documented**: a boundary test fails if any package other than `CNCPipeline` and `CNCGCode` can reach a file-writing API, and a lexical test asserts no laser token (`M4`, `$32`, `S`-as-power, `G0` dynamic-power comments) is ever emitted. Both prohibitions now have executable guards.
- **Material resolution has one home**: `CNCMaterials` returns `.resolved` or `.noOverlap`, so FR-079's prefill rule and FR-080's rejection rule are testable without a planner or a UI.
- **Deletion propagation (FR-060, H8) is explicit**: `CNCCuttersStore` exposes an `AsyncStream` of library changes from one store value created in the composition root. Both presentations receive that store, never each other. No shared mutable state exists; the persisted document stays the contract.
- **Rapid ceiling**: recorded interpretation above, with a recommended PATCH amendment.
- **80-character line limit**: emitted from one formatter and checked by the validator, so `CNCGCode` and `CNCValidation` agree on the ceiling without sharing code.
- **Determinism**: `generatedAt` is an injected `Date`, so the determinism test uses two fixed clocks and no real time (Principle III, H9).
- **Presentation separation**: `MainScreenUI` and `CutterLibraryModalUI` still never import each other; the library-to-generation contract test runs from the neutral `CNCPipeline` test target, which may import both (H6).

## Task-shaping notes for `/speckit.tasks`

The task list is regenerated after this plan. These points must appear in it, because the previous `tasks.md` predates the material feature and placed orchestration and writer tests in packages that are forbidden to import them:

1. **Package placement.** Writer implementation and its atomic-write tests both go in `CNCGCode`. Orchestration and its end-to-end test go in `CNCPipeline`. No task may add a `CNCGCode` or `CNCValidation` import to `CNCToolpath`.
2. **Material tasks.** Preset table plus fixture, band entry validation, the resolution function with both prefill paths, the empty-overlap rejection, user-material storage, and the material rows in the header. Without these, FR-077 – FR-081 and SC-013 have no coverage.
3. **Guard tasks for FR-030 and FR-031.** A boundary test asserting no serial or hardware surface exists outside an explicitly empty allow-list, and a lexical test asserting no laser token (`M4`, `$32`, dynamic-power comments) can reach output. Both were previously prose only.
4. **Library-to-generation contract test.** It runs from the `CNCPipeline` test target, which may import both presentation modules' dependencies without making either presentation import the other (H6). It also covers the cutter-deletion stream (FR-060).
5. **Injected clock and file system.** Determinism and writer tests take a fixed `Date` and a fake file system; no test reads the system clock or Application Support (Principle III, H9).
6. **UI placement of the rapid-rate confirmation.** It belongs in the material panel's job section plus the pre-generation checklist, not as a fourth panel, because FR-055 fixes the count at three.
7. **Identifier immutability test** for cutters and materials across edit, save, and migration (H1, FR-042).
8. **Measurable feature rule.** The "feature smaller than the cutter" report needs a numeric definition in the implementation — smallest concave feature radius against the cutter's effective radius at the finishing stepover (H4) — so the test asserts a number, not an adjective.

## Complexity Tracking

| Deviation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| No checked-in `.xcodeproj`; app bundle assembled by `Scripts/make-app.sh` | Xcode is not installed on this machine (verified), so no Xcode project can be built or validated here. SPM plus a bundle script keeps `swift build`/`swift test` as the single source of truth. | Hand-writing a `project.pbxproj` that cannot be opened or verified would be unverifiable output. Principle II's Xcode clause is conditional on a project existing; none will exist, and `Package.swift` still opens as a project wherever Xcode is present, with zero duplicated sources. |
| Swift Testing invoked with `-load-plugin-library` pointing at `libTestingMacros.dylib` | Command Line Tools ships the macro plugin under `host/plugins/testing/`, which SwiftPM does not search, so a bare `swift test` fails. | Falling back to XCTest was rejected: Principle III mandates Swift Testing, and XCTest is not even present in the CLT toolchain. Installing Xcode is the only alternative and is outside this feature's scope. |
| RealityKit for the 3D preview | SceneKit is soft-deprecated from macOS 26 (verified), and the deployment floor is 27.0. | SceneKit is a maintenance-mode framework on a new app — Principle IV's "first-class macOS" intent argues against building a new feature on it. Metal directly was rejected as more code for no product benefit. |
| Sixteen packages instead of eleven | The material feature adds one owner for bands and resolution, one store for user materials, one shared storage package, and orchestration needs a package that may import every stage. | Folding materials into `CNCToolpath` and orchestration into the app target was rejected: it makes FR-079/FR-080 untestable without a UI, and leaves the pipeline's only integration test in a target that links SwiftUI. |
