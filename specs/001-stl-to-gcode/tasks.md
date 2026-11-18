---

description: "Task list for STL to Machine-Ready G-code implementation"
---

# Tasks: STL to Machine-Ready G-code

**Input**: Design documents from `/specs/001-stl-to-gcode/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Required. Constitution Principle III makes test-first non-negotiable: write the test, prove it fails for the right reason, then implement.

**Organization**: Tasks are grouped by user story so each story can be implemented and tested independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel with other `[P]` tasks in the same wave (different files, no shared dependency).
- **[Story]**: required only in user-story phases; setup, foundational, and polish tasks carry no story label.
- Every task names a concrete file or directory path.
- Task format: `- [ ] TNNN [P] [USn] Description (FR-xxx, SC-xxx) — path`.

## Path Conventions

This is a Swift Package Manager workspace, not a single `src/` tree.

- Root workspace: `Package.swift`
- Local packages: `Packages/<PackageName>/Sources/`, `Packages/<PackageName>/Tests/`
- App shell: `App/Sources/CNCswiftApp/`, `App/Resources/`
- Fixtures: `Fixtures/stl/`, `Fixtures/gcode/`, `Fixtures/library/`, `Fixtures/materials/`
- Scripts: `Scripts/`

## Specification conflicts resolved in design artifacts

Do not silently rewrite `spec.md` while implementing. The clarified spec, `plan.md`, contracts, and data model are the executable source of truth. Where `spec.md` still contains a literal conflict, follow the resolution below and raise a spec refinement if behaviour changes:

1. **Commit gate vs. US1 acceptance scenario 1**: clarification Q6 and `contracts/toolpath-api.md` say `run` builds, validates, and previews without writing; a separate explicit `commit` writes after the preview is shown and findings are acknowledged. US1 acceptance scenario 1 says generation writes a file. Implementation follows Q6 and the contract; US1 tests use a test-only confirmation after a stub preview. Do not make `run` write.
2. **Validation vs. preview findings**: validation errors block writing. The preview highlights envelope and limit findings; it does not make an invalid program committable.
3. **SC-012 threshold vs. five reference models**: 95% of five fixtures is still five fixtures under the current reference set. Record timings for all five; a lower threshold needs an amendment to the reference set or the criterion.
4. **Preset bands**: the four band rows are provisional engineering guidance pending cutting-experience sign-off (research D11). Keep the fixture marked provisional until T111 records approval.
5. **FR-041 effective radius**: resolved in `plan.md` task-shaping note 8 and `data-model.md`. `CNCGeometry` owns `effectiveRadius(cutter, stepover)`: flat = `cuttingDiameter / 2`; ball nose = `sqrt(2Rs - s²)` with `R = ballDiameter / 2` and `s = min(stepover, R)`; V-bit = `tipDiameter / 2 + s * tan(includedAngle / 2)`. T050 and T065 assert this formula and report both radii in millimetres.
6. **FR-029 header fields**: treat `contracts/gcode-output.md` plus FR-081 as the canonical header field list, including the rapid-rate line and the material rows.
7. **ASCII-only output**: `contracts/gcode-output.md` defines deterministic 7-bit ASCII content and filenames. U+2026 is forbidden; truncation uses the three ASCII characters `...`.
8. **Laser tokens**: `M4` and `$32` are unsupported dynamic-power tokens in `contracts/machine-profile.md`; T012, T026, T044, and T047 enforce the rejection.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Workspace, Swift 6 settings, build/test/bundle tooling, entitlements, and fixture skeleton. No product behaviour yet.

- [X] T001 Create the root `Package.swift` with Swift 6 language mode, complete concurrency checking, warnings as errors, sixteen local packages, and the `CNCswiftApp` executable target — `Package.swift`
- [X] T002 [P] Add package skeletons with a source and Swift Testing test target for all sixteen packages: `CNCMachineProfile`, `CNCDiagnostics`, `CNCStorage`, `CNCGeometry`, `CNCSTL`, `CNCCutters`, `CNCCuttersStore`, `CNCMaterials`, `CNCMaterialsStore`, `CNCToolpath`, `CNCGCode`, `CNCValidation`, `CNCSimulation`, `CNCPipeline`, `MainScreenUI`, `CutterLibraryModalUI` — `Packages/*/Package.swift`
- [X] T003 [P] Add the app skeleton with an `@main` entry point and a `SwiftUI.Scene` body so RealityKit's `Scene` name does not create ambiguity (research D3) — `App/Sources/CNCswiftApp/CNCswiftApp.swift`
- [X] T004 [P] Add the Swift-format configuration referenced by the format gate — `.swift-format`
- [X] T005 [P] Add `ci.sh` resolving the Swift Testing macro plugin path dynamically, then running format lint, build, and test in order (research D2) — `Scripts/ci.sh`
- [X] T006 [P] Add `make-app.sh` assembling `CNCswift.app` from the built executable with `Info.plist`, bundle identifier `com.hansvanderpol.CNCswift`, and ad-hoc signing via `/usr/bin/codesign --sign -` (FR-075, FR-076, constitution v4.3.0) — `Scripts/make-app.sh`, `App/Resources/Info.plist`
- [X] T007 [P] Add sandbox entitlements declaring app sandbox and user-selected file read/write only; no hardware or network entitlement (FR-073) — `App/Resources/CNCswift.entitlements`
- [X] T008 [P] Create fixture directories and `Fixtures/README.md` enumerating exactly five versioned reference models — ASCII relief, binary relief, 200,000-triangle relief, deep cavity, fine-detail relief — with each file's purpose and an amendment note for adding/removing models (SC-003, SC-012, clarification Q5) — `Fixtures/README.md`
- [X] T009 [P] Add the five reference STL fixtures named in `Fixtures/README.md`: `relief-demo-ascii.stl`, `relief-demo-binary.stl`, `relief-demo-200k.stl`, `deep-cavity.stl`, `fine-detail.stl` — `Fixtures/stl/`
- [X] T010 [P] Add ignore rules for `.build/`, `.DS_Store`, generated `.app` bundles, and `.idea/` — `.gitignore`
- [X] T011 [P] Record the real build, test, format, and bundle commands and remove stale repository-state claims — `AGENTS.md`

**Checkpoint**: `swift build` succeeds on empty targets and `Scripts/ci.sh` runs green.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Value types and guarantees every story depends on: profile, geometry, decoding, cutters, materials, diagnostics, storage, and package boundaries. No pipeline orchestration or UI behaviour exists yet.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

### Tests for Foundation (write first; they must fail)

- [X] T012 [P] Test profile decoding, exact ordered blocks, limit invariants, `$110`-`$112`/`$30`/`$31` controller-setup values, `G94`-only feed mode, rejection of unsupported `G43`/`G43.1`/`G49`/`G93`/`M4`/`M6`/`M7`/`$32`, unknown-dialect rejection, and inconsistent rapid-setup rejection (FR-013, FR-014, FR-015, FR-016, FR-017, FR-024, FR-031) — `Packages/CNCMachineProfile/Tests/MachineProfileTests.swift`
- [X] T013 [P] Test vector, AABB, mesh invariants, explicit model-to-machine transform, front-left-top origin, BVH ray-cast heights against a brute-force scan, and `effectiveRadius` for flat (`cuttingDiameter / 2`), ball nose (`sqrt(2Rs - s^2)` with `R = ballDiameter / 2` and `s = min(stepover, R)`), and V-bit (`tipDiameter / 2 + s * tan(includedAngle / 2)`) geometry (FR-007, FR-009, FR-012, FR-041) — `Packages/CNCGeometry/Tests/GeometryTests.swift`
- [X] T014 [P] Test content-based ASCII/binary STL decoding, rejection of truncated/empty/degenerate/non-manifold files with file and defect named, and progress reporting at 50,000+ triangles (FR-001, FR-002, FR-003, FR-004, FR-069) — `Packages/CNCSTL/Tests/STLDecoderTests.swift`
- [X] T015 [P] Test the closed cutter taxonomy, per-type required and forbidden fields, every entry-validation rule, shank dominance (`shankDiameter >= maxCuttingExtent`, where `maxCuttingExtent` is `cuttingDiameter` for flat, `ballDiameter` for ball nose, and `tipDiameter + 2 * cuttingLength * tan(includedAngle / 2)` for V-bit), rejection when a V-bit tip merely fits the shank, and identifier immutability after edit (FR-042, FR-044, FR-045, FR-046, FR-047, FR-048) — `Packages/CNCCutters/Tests/CutterValidationTests.swift`
- [X] T016 [P] Test the four preset names and ordered positive bands, plus entry rejection for non-positive bounds, inverted bounds, empty names, duplicate names, and preset shadowing (FR-077, FR-078) — `Packages/CNCMaterials/Tests/MaterialPresetTests.swift`
- [X] T017 [P] Test both prefill paths, `confirmed: false`, user choice inside the intersection, impossible construction of an out-of-intersection value, and `.noOverlap(.feed)`/`.noOverlap(.spindle)` messages naming material, band, and ceiling or floor (FR-079, FR-080, FR-040, SC-004, SC-013) — `Packages/CNCMaterials/Tests/ResolutionTests.swift`
- [X] T018 [P] Test typed stage errors carrying stable correlation identifiers shared with per-module `os.Logger` records and an actionable user message (FR-067, FR-068) — `Packages/CNCDiagnostics/Tests/DiagnosticsTests.swift`
- [X] T019 [P] Test progress reporting and cooperative cancellation through `ProgressSink`, with cancellation distinct from failure (FR-069) — `Packages/CNCDiagnostics/Tests/CancellationTests.swift`
- [X] T020 [P] Test atomic replace, backup retention, schema stamping, forward migration, and newer-schema refusal using an injected fake file system (FR-051 parity, FR-052 parity, FR-053, FR-054) — `Packages/CNCStorage/Tests/StorageTests.swift`
- [X] T021 [P] Add the build-graph guard failing on forbidden imports: `CNCValidation` → `CNCGCode`, `CNCToolpath` → `CNCGCode`/`CNCValidation`/`CNCPipeline`, domain → SwiftUI/RealityKit, presentation cross-imports, and any stage → `CNCPipeline` (FR-015, FR-059, C1, C2) — `Packages/CNCPipeline/Tests/BoundaryTests.swift`
- [X] T022 [P] Test cutter store load/save round trips against an injected file system, including backup creation and `loaded`/`migrated(from:)`/`absent` outcomes (FR-051, FR-052, FR-054) — `Packages/CNCCuttersStore/Tests/LibraryStoreTests.swift`
- [X] T023 [P] Test newer-schema refusal and corrupt-file handling, asserting the original file is byte-identical and the path is reported (FR-053, FR-054) — `Packages/CNCCuttersStore/Tests/LoadOutcomeTests.swift`
- [X] T024 [P] Test cutter identifier immutability across edit, save, reload, and migration (FR-042, FR-050, FR-052) — `Packages/CNCCuttersStore/Tests/IdentifierTests.swift`
- [X] T025 [P] Test `.saved`, `.deleted(id:)`, and `.reloaded` change-stream events, buffered delivery, no event on failed save, and no shared mutable record payload (FR-058, FR-060, D14) — `Packages/CNCCuttersStore/Tests/ChangeStreamTests.swift`

### Implementation for Foundation

- [X] T026 Implement profile value types and the versioned TTC450 PRO GRBL 1.1 profile data with `G94`-only feed mode, `M4`/`$32`/`G93`/`G43.1`/`G49` listed as unsupported, controller setup descriptive and never emitted, and every limit in the profile rather than code (FR-013, FR-014, FR-015, FR-016, FR-017, FR-018, FR-024, FR-025, FR-031) — `Packages/CNCMachineProfile/Sources/TTC450Pro.swift`
- [ ] T027 Implement `Vec3`, `Mesh`, `AABB`, BVH height queries, the explicit model-to-machine transform, the front-left-top origin convention, and the `effectiveRadius` helper for flat, ball-nose, and V-bit geometry using the formulas from plan task-shaping note 8 (FR-007, FR-009, FR-012, FR-041, D5) — `Packages/CNCGeometry/Sources/`
- [ ] T028 Implement content-based ASCII/binary STL detection, decoding, defect reporting, and 50,000+ triangle progress without repair, rescale, or hole filling (FR-001, FR-002, FR-003, FR-004, FR-069, D4) — `Packages/CNCSTL/Sources/STLDecoder.swift`
- [ ] T029 Implement the closed cutter type hierarchy, type-specific dimensions, `maxCuttingExtent` for each type, shank dominance requiring `shankDiameter >= maxCuttingExtent`, and entry validation rejecting another type's field as a substitute (FR-042, FR-044, FR-045, FR-046, FR-047, FR-048) — `Packages/CNCCutters/Sources/`
- [ ] T030 Implement `Material`, the four built-in read-only presets, and band validation; mark preset values provisional pending sign-off (FR-077, FR-078, research D11) — `Packages/CNCMaterials/Sources/Presets.swift`
- [ ] T031 Implement `EffectiveCuttingValues.resolve(material:cutter:profile:)` as the only feed/spindle resolution site, returning `.resolved(confirmed: false)` or a named `.noOverlap` conflict (FR-079, FR-080, FR-040, SC-013) — `Packages/CNCMaterials/Sources/Resolution.swift`
- [ ] T032 Implement shared atomic write, versioned document envelope, backup retention, and the forward-only migration runner used by both stores (FR-051 parity, FR-052 parity, FR-053, FR-054, D9) — `Packages/CNCStorage/Sources/`
- [ ] T033 Implement typed stage errors with correlation identifiers and per-module structured logging categories (FR-067, FR-068) — `Packages/CNCDiagnostics/Sources/`
- [ ] T034 Implement `ProgressSink` and cooperative `Task.cancel()` handling via `withTaskCancellationHandler` (FR-069, D10) — `Packages/CNCDiagnostics/Sources/Cancellation.swift`
- [ ] T035 Declare the typed stage protocols and shared value types from `contracts/toolpath-api.md` in their owning packages so every story compiles against the same boundaries — `MaterialResolving`, `ToolpathPlanning`, `GCodeRendering`, `ProgramWriter`, `ProgramValidating`, `MaterialRemovalSimulating`, `PipelineRunning`, `RenderedProgram`, `ParsedProgram`, `SimulationResult`, `GenerationRequest`, `PipelineOutcome`, `WriteConfirmation` (FR-026, FR-027, D7, D10, C1, C2) — `Packages/CNCToolpath/Sources/Protocols.swift`, `Packages/CNCGCode/Sources/Protocols.swift`, `Packages/CNCValidation/Sources/Protocols.swift`, `Packages/CNCSimulation/Sources/Protocols.swift`, `Packages/CNCPipeline/Sources/Protocols.swift`
- [ ] T036 Implement cutter library load with all load outcomes, each reported with its path (FR-051, FR-053, FR-054) — `Packages/CNCCuttersStore/Sources/LibraryStore.swift`
- [ ] T037 Publish `AsyncStream<LibraryChange>` from the single store actor only after successful atomic save (FR-060, D14) — `Packages/CNCCuttersStore/Sources/Changes.swift`
- [ ] T038 Add a current-schema cutter fixture used by store tests and as the seeded cutter for US1 (FR-051, FR-042) — `Fixtures/library/current.json`
- [ ] T039 Add the preset-band fixture asserting exactly four shipped bands, preserved names, ordered positive bounds, and a provisional-status marker (FR-077, research D11) — `Fixtures/materials/presets.json`, `Fixtures/materials/README.md`

**Checkpoint**: Foundational tests pass; no generation pipeline or UI exists yet.

---

## Phase 3: User Story 1 — Generate a validated G-code file from an STL (Priority: P1) 🎯 MVP

**Goal**: Decode an STL, resolve material-based cutting values, plan roughing plus raster finishing, render a deterministic `.nc`, validate it independently, and expose an explicit commit path for writing, driven by the first two main-screen panels.

**Independent Test**: With a material constructed in memory and a cutter loaded from the seeded stored library, run the pipeline from `Fixtures/stl/relief-demo-binary.stl`, confirm `run` writes nothing, inspect the rendered text for start block first, stop block last, every line ≤80 characters, no `F` on a rapid, all coordinates inside 460 × 460 × 80, and deterministic bytes with an injected clock, then call `commit` once with a test confirmation and inspect the single `.nc` file (quickstart VS-1, VS-2, VS-3, VS-4, VS-9; clarification Q6).

### Tests for User Story 1 (write first; they must fail)

- [ ] T040 [P] [US1] Golden-file test for header field order, cutter and material rows, effective values, rapid-rate basis, start block, stop block, and three-decimal formatting (FR-019, FR-020, FR-021, FR-029, FR-081) — `Packages/CNCGCode/Tests/EmitterTests.swift`
- [ ] T041 [P] [US1] Rapid-rate header test asserting `; rapid-rate: controller 800 (see $110-$112)`, no `F` on any `G0`, and no rapid rate claimed as program text (FR-024, FR-081) — `Packages/CNCGCode/Tests/RapidHeaderTests.swift`
- [ ] T042 [P] [US1] Determinism test using two injected `Date` values: files differ only on `; generated:` (FR-028, SC-005, D8) — `Packages/CNCGCode/Tests/DeterminismTests.swift`
- [ ] T043 [P] [US1] Line-length and ASCII test asserting every emitted line including header and comments is at most 80 characters, every content byte is 7-bit ASCII, U+2026 is rejected, over-long values truncate with the three ASCII characters `...`, and an over-long case throws (FR-018, FR-082, D8) — `Packages/CNCGCode/Tests/LineLengthTests.swift`
- [ ] T044 [P] [US1] Output guard test asserting no laser token (`M4`, `$32`, `S`-as-power, dynamic-power comments), `$` setting, `G43`, `G43.1`, `G49`, `G93`, `M6`, or unsupported command can reach output (FR-017, FR-031) — `Packages/CNCGCode/Tests/OutputGuardTests.swift`
- [ ] T045 [P] [US1] Writer tests against an injected fake file system: atomic replace, `.nc` extension only, deterministic ASCII filename (drop extension, map characters outside `[A-Za-z0-9._-]` to `_`, collapse `_` runs, append `.nc`, fall back to `carve.nc`), no partial file on failure, and no file on cancellation (FR-018, FR-027, SC-011) — `Packages/CNCGCode/Tests/FileWriterTests.swift`
- [ ] T046 [P] [US1] Independent parser tests for the GRBL 1.1 subset, unknown words, modal-state tracking, and line-length findings (FR-026, D7) — `Packages/CNCValidation/Tests/ParserTests.swift`
- [ ] T047 [P] [US1] Semantic rule tests for boundary-inclusive envelope, feed and spindle ceilings, `F` on rapid, block order, `M5` before origin return, `M30` final, and rejection of `$`, `M4`, `$32`, `G93`, `G43.1`, and `G49` words (FR-022, FR-023, FR-024, FR-025, FR-026, FR-031, SC-002, SC-003) — `Packages/CNCValidation/Tests/RuleTests.swift`
- [ ] T048 [P] [US1] Planner tests for layer depth bound, finishing allowance, stepover bound, footprint margin, clearance-height rapids, per-cut effective feed, and rejection of maximum depth above cutter cutting length (FR-032, FR-033, FR-034, FR-035, FR-036, FR-038, FR-039, FR-040) — `Packages/CNCToolpath/Tests/PlannerTests.swift`
- [ ] T049 [P] [US1] Preflight rejection tests for unconfirmed units/orientation, non-positive or oversize stock, model outside stock, missing cutter attribute, unconfirmed rapid setup, and `cuttingLength < stock.height` (cutter reach), naming the required cutting length; assert exact 460/460/80 is accepted (FR-005, FR-010, FR-011, FR-024, FR-025, FR-033, FR-037, FR-049) — `Packages/CNCToolpath/Tests/PreflightTests.swift`
- [ ] T050 [P] [US1] Numeric feature-size test using `CNCGeometry.effectiveRadius(cutter, stepover)` with the flat/ball-nose/V-bit formulas from plan task-shaping note 8, asserting `smallestConcaveRadius < effectiveRadius` blocks generation and reports both radii in millimetres, not an adjective (FR-041, plan task-shaping note 8) — `Packages/CNCToolpath/Tests/FeatureTests.swift`
- [ ] T051 [P] [US1] Material-library round-trip and persistence tests against an injected file system, including preset merge, no preset shadowing, and newer-schema refusal (FR-077 persistence) — `Packages/CNCMaterialsStore/Tests/MaterialStoreTests.swift`
- [ ] T052 [P] [US1] Pipeline test proving `run` returns `.ready` without writing, then a test confirmation through `commit` writes exactly one `.nc`; blocked and cancelled simulations cannot be committed (FR-026, FR-064, FR-069, SC-011, clarification Q6) — `Packages/CNCPipeline/Tests/PipelineTests.swift`
- [ ] T053 [P] [US1] Pipeline cancellation test asserting no `.nc` and no temporary file remain and the outcome is `.cancelled`, not a failure (FR-069, SC-011) — `Packages/CNCPipeline/Tests/CancellationTests.swift`
- [ ] T054 [P] [US1] Library-to-generation contract test from the neutral pipeline target: a cutter created or edited in the modal is selected on the main screen and flows into the next header by identifier without relaunch, with both effective values inside the intersection (FR-050, FR-079, FR-081, SC-007, SC-013) — `Packages/CNCPipeline/Tests/GenerationContractTests.swift`
- [ ] T055 [P] [US1] View-model tests for blocked states: unconfirmed effective values, unconfirmed job strategy, unconfirmed rapid setup, empty material overlap, and empty cutter selection (FR-024, FR-037, FR-040, FR-080) — `Packages/MainScreenUI/Tests/MainScreenModelTests.swift`
- [ ] T056 [P] [US1] Job-strategy prefill test proving stepover, maximum depth per pass, and finishing allowance are suggested but not applied until confirmed, separately from cutting-value confirmation (FR-037) — `Packages/MainScreenUI/Tests/JobSettingsTests.swift`

### Implementation for User Story 1

- [ ] T057 [US1] Implement the emitter and header builder with profile blocks, invariant three-decimal formatting, injected `generatedAt`, 80-character guard, 7-bit ASCII sanitization of all header strings, ASCII truncation with `...`, deterministic ASCII filename derivation, cutter values, material bands, effective values, and the rapid-rate basis line (FR-006, FR-007, FR-018, FR-019, FR-020, FR-021, FR-022, FR-024, FR-029, FR-081, FR-082, D8) — `Packages/CNCGCode/Sources/Emitter.swift`, `Packages/CNCGCode/Sources/GenerationRecord.swift`
- [ ] T058 [US1] Implement rapid formatting so every `G0` line has no `F` or `S`, follows clearance-height sequencing, and re-emits modal `G1` with feed after a rapid (FR-024, FR-039) — `Packages/CNCGCode/Sources/RapidFormatter.swift`
- [ ] T059 [US1] Implement the atomic `.nc` writer behind an injected file system, emitting one file with the profile extension only (FR-018, FR-027) — `Packages/CNCGCode/Sources/FileWriter.swift`
- [ ] T060 [US1] Implement the independent GRBL 1.1 line parser producing `ParsedProgram` (FR-026, D7) — `Packages/CNCValidation/Sources/Parser.swift`
- [ ] T061 [US1] Implement semantic rules and a findings report with line numbers, rule identifiers, and a correlation identifier (FR-022, FR-023, FR-024, FR-025, FR-026, FR-031, FR-067) — `Packages/CNCValidation/Sources/Rules.swift`
- [ ] T062 [US1] Implement layered roughing down to the finishing allowance with per-layer depth bound and no whole-blank sweep (FR-032, FR-033, FR-034, FR-038) — `Packages/CNCToolpath/Sources/RoughingPlanner.swift`
- [ ] T063 [US1] Implement finishing raster passes with drop-cutter correction for flat, ball-nose, and V-bit geometry, derived from the selected cutter (FR-032, FR-035, FR-036, D5, D6) — `Packages/CNCToolpath/Sources/FinishingPlanner.swift`
- [ ] T064 [US1] Implement model-footprint-plus-one-radius restriction and clearance-height rapid sequencing that never rapids through material (FR-038, FR-039) — `Packages/CNCToolpath/Sources/Footprint.swift`, `Packages/CNCToolpath/Sources/MoveSequencer.swift`
- [ ] T065 [US1] Implement preflight checks, suggested-but-unconfirmed settings, the numeric too-small-feature report using `CNCGeometry.effectiveRadius(cutter, stepover)` and the formulas from plan task-shaping note 8, and explicit rejection when `cuttingLength < stock.height` with the required length named (FR-005, FR-010, FR-011, FR-033, FR-037, FR-041, FR-049) — `Packages/CNCToolpath/Sources/Preflight.swift`
- [ ] T066 [US1] Implement user-material load and atomic save over `CNCStorage` with presets merged at load and never shadowed (FR-077) — `Packages/CNCMaterialsStore/Sources/LibraryStore.swift`
- [ ] T067 [US1] Implement the `ToolpathService.run` actor path orchestrating decode → plan → render → validate → preview-ready result with injected clock, injected file system, progress, and cancellation; this is the only package importing all stages (FR-069, D10, C1) — `Packages/CNCPipeline/Sources/ToolpathService.swift`
- [ ] T068 [US1] Implement the minimal explicit `commit(_:confirmation:to:)` path that calls `CNCGCode.ProgramWriter` only from `PipelineRunning.commit`, writes only a validated rendered program after a supplied confirmation, and leaves `run` with no file write; US3 hardens confirmation provenance (FR-026, FR-027, SC-011, clarification Q6) — `Packages/CNCPipeline/Sources/ToolpathService.swift`
- [ ] T069 [US1] Implement the main-screen shell with exactly three panels, the third present as a labelled placeholder until US3 (FR-055, FR-009) — `Packages/MainScreenUI/Sources/MainScreen.swift`
- [ ] T070 [US1] Implement the cutter-selection panel listing stored cutters from the Foundational store and consuming them read-only (FR-043, FR-055) — `Packages/MainScreenUI/Sources/CutterPanel.swift`
- [ ] T071 [US1] Implement the material panel: material picker showing bands, stock dimensions, prefilled effective feed and spindle with explicit confirmation, and rapid-rate controller-setting confirmation inside the job section and pre-generation checklist rather than a fourth panel (FR-008, FR-009, FR-010, FR-024, FR-040, FR-055, FR-077, FR-079, FR-080, plan task-shaping note 6) — `Packages/MainScreenUI/Sources/MaterialPanel.swift`
- [ ] T072 [US1] Implement the units and orientation confirmation sheet and the explicit-scale action; no assumption of millimetres and no unconfirmed scale (FR-005, FR-006) — `Packages/MainScreenUI/Sources/ConfirmUnitsSheet.swift`
- [ ] T073 [US1] Implement the main-screen view model and generate controls with blocked states, progress, cancel, and no unconfirmed value applied (FR-037, FR-040, FR-049, FR-060, FR-069) — `Packages/MainScreenUI/Sources/MainScreenModel.swift`, `Packages/MainScreenUI/Sources/GenerateControls.swift`
- [ ] T074 [US1] Commit reviewed golden `.nc` files as production output, including material, effective-value, and rapid-rate header rows (FR-028, SC-003, Development Workflow gate) — `Fixtures/gcode/`
- [ ] T075 [US1] Wire the pipeline, profile, cutters, and materials into the app composition root (FR-057) — `App/Sources/CNCswiftApp/Composition.swift`

**Checkpoint**: US1 renders, validates, and can explicitly commit a deterministic `.nc` from a stored cutter and an in-memory material. Stop and run quickstart VS-1, VS-2, VS-3, VS-4, and VS-9.

---

## Phase 4: User Story 2 — Maintain the cutter library in a modal (Priority: P2)

**Goal**: Complete forward-only cutter migrations and present cutter maintenance in a module separate from the main screen; load, save, and change notification are already Foundational.

**Independent Test**: Open the modal from a main screen with no library loaded, create one flat, one ball-nose, and one V-bit cutter, relaunch, and confirm all three identifiers and values survive; load a v1 fixture with a v2 build and confirm no record loss (quickstart VS-6, VS-7).

### Tests for User Story 2 (write first; they must fail)

- [ ] T076 [P] [US2] Migration tests across two consecutive versions with v1 and v2 fixtures, including abort without loss for an unmigratable record (FR-052, SC-008) — `Packages/CNCCuttersStore/Tests/MigrationTests.swift`
- [ ] T077 [P] [US2] Modal view-model tests for per-type forms, entry rejection at the field, and the empty-library path to a first valid cutter (FR-044, FR-045, FR-046, FR-048, SC-006) — `Packages/CutterLibraryModalUI/Tests/CutterEditorModelTests.swift`
- [ ] T078 [P] [US2] Timed first-valid-cutter scenario test proving a user can go from an empty library to a stored valid cutter without help (SC-006) — `Packages/CutterLibraryModalUI/Tests/EmptyLibraryTests.swift`
- [ ] T079 [P] [US2] Cutter-deletion contract test from the neutral pipeline target: the main screen clears its selection and generation is blocked until a stored cutter is chosen (FR-060, SC-007) — `Packages/CNCPipeline/Tests/DeletionContractTests.swift`
- [ ] T080 [P] [US2] Module-independence test proving the modal entry point and view model run without the main screen module loaded (FR-057) — `Packages/CutterLibraryModalUI/Tests/ModuleIndependenceTests.swift`

### Implementation for User Story 2

- [ ] T081 [US2] Implement the forward-only cutter migration chain using `CNCStorage` (FR-052) — `Packages/CNCCuttersStore/Sources/Migrations.swift`
- [ ] T082 [US2] Implement the modal module entry point and cutter list as a module usable without the main screen running (FR-056, FR-057) — `Packages/CutterLibraryModalUI/Sources/LibraryModal.swift`
- [ ] T083 [US2] Implement per-type editor forms requesting exactly the dimensions of the chosen type, with no bare-diameter substitute (FR-045, FR-046, FR-047) — `Packages/CutterLibraryModalUI/Sources/CutterEditor.swift`
- [ ] T084 [US2] Implement field-level entry-validation messaging naming the rule and limit; never defer to generation time (FR-048) — `Packages/CutterLibraryModalUI/Sources/CutterEditorModel.swift`
- [ ] T085 [US2] Implement modal edit and delete operations that publish through the store and hold no main-screen reference (FR-058, FR-059) — `Packages/CutterLibraryModalUI/Sources/LibraryModalModel.swift`
- [ ] T086 [US2] Subscribe the main-screen view model to the change stream, re-resolve the selected cutter identifier, and block generation on a stale or deleted selection (FR-060, FR-058) — `Packages/MainScreenUI/Sources/MainScreenModel.swift`
- [ ] T087 [US2] Add the Cutter Library command, modal presentation, and composition-root wiring so one store is injected into both modules (FR-056, FR-057, FR-072) — `App/Sources/CNCswiftApp/Commands.swift`, `App/Sources/CNCswiftApp/Composition.swift`
- [ ] T088 [US2] Commit reviewed cutter schema v1 and v2 fixtures used by the migration tests (FR-052, SC-008) — `Fixtures/library/`

**Checkpoint**: US1 already consumes cutters from the persisted library; US2 now adds migration and the modal. Run quickstart VS-6 and VS-7.

---

## Phase 5: User Story 3 — Preview the carve in 3D before writing the file (Priority: P3)

**Goal**: Render the validated program as a 3D z-map material-removal preview in the third panel, distinguish rapids, name violations, and make the final write conditional on an explicit commit after the preview.

**Independent Test**: From a fixture `ParsedProgram` with no generation pipeline, confirm the preview shows the stock with removed material following the surface, rapids remove nothing, and an out-of-envelope move is highlighted and named; separately confirm `run` writes nothing and `commit` cannot be called after a blocked or cancelled simulation (quickstart VS-5, clarification Q6).

### Tests for User Story 3 (write first; they must fail)

- [ ] T089 [P] [US3] Z-map tests: cutting moves lower the heightmap, rapids do not, and roughing plus finishing produce the expected depths (FR-061, FR-062, FR-063) — `Packages/CNCSimulation/Tests/ZMapTests.swift`
- [ ] T090 [P] [US3] Preview-mesh tests for deterministic vertices and normals from a known heightmap (FR-061) — `Packages/CNCSimulation/Tests/PreviewMeshTests.swift`
- [ ] T091 [P] [US3] Violation-surfacing tests asserting envelope and limit findings are named before writing and that a violation prevents commit (FR-064, FR-065) — `Packages/CNCSimulation/Tests/ViolationsTests.swift`
- [ ] T092 [P] [US3] Progress and cancellation tests asserting a cancelled simulation is reported as cancelled, not failed (FR-066, FR-069) — `Packages/CNCSimulation/Tests/CancellationTests.swift`
- [ ] T093 [P] [US3] Identity test proving simulation consumes the exact `ParsedProgram` returned by validation, not an emitter-side toolpath (FR-065) — `Packages/CNCSimulation/Tests/ProgramIdentityTests.swift`
- [ ] T094 [P] [US3] Commit-gate test proving no file exists after `run`, no file after a blocked or cancelled simulation, and a file only after `commit` with preview shown and findings acknowledged (FR-064, FR-066, FR-069, SC-011, clarification Q6) — `Packages/CNCPipeline/Tests/CommitTests.swift`
- [ ] T095 [P] [US3] Render-time test recording preview latency for all five reference STL fixtures and asserting 5/5 fixtures render within five seconds, because 95% of the five-fixture reference set requires five passes (SC-012, clarification Q5) — `Packages/CNCSimulation/Tests/PreviewPerformanceTests.swift`

### Implementation for User Story 3

- [ ] T096 [US3] Implement cutter-sweep z-map removal from `ParsedProgram` with documented stock-space resolution and no removal on rapids (FR-061, FR-062, FR-063, FR-065) — `Packages/CNCSimulation/Sources/ZMap.swift`
- [ ] T097 [US3] Implement heightmap-to-mesh conversion with computed normals for RealityKit (FR-061) — `Packages/CNCSimulation/Sources/PreviewMesh.swift`
- [ ] T098 [US3] Implement collection of named envelope and limit violations from the validated program (FR-064) — `Packages/CNCSimulation/Sources/Violations.swift`
- [ ] T099 [US3] Implement the `RealityView` preview panel in the third slot, qualifying the app scene as `SwiftUI.Scene` (FR-055, FR-061, D3) — `Packages/MainScreenUI/Sources/SimulationPanel.swift`
- [ ] T100 [US3] Implement camera and keyboard navigation for the 3D preview, with rapids visually distinct from cuts (FR-063, FR-070) — `Packages/MainScreenUI/Sources/SimulationCamera.swift`
- [ ] T101 [US3] Implement simulation progress, cancel, and the violation list above the preview (FR-064, FR-066, FR-069) — `Packages/MainScreenUI/Sources/SimulationModel.swift`
- [ ] T102 [US3] Replace the US1 stub simulator in `ToolpathService` with the real simulator, keeping validate → simulate → commit order and no write in `run` (FR-061, FR-065, clarification Q6) — `Packages/CNCPipeline/Sources/ToolpathService.swift`
- [ ] T103 [US3] Harden `commit` so it requires `previewShown == true`, zero unacknowledged error findings, no simulation violations, and a non-cancelled simulation before writing (FR-026, FR-064, FR-066, SC-011, clarification Q6) — `Packages/CNCPipeline/Sources/ToolpathService.swift`

**Checkpoint**: All three stories work independently; the main screen has its three mandated panels and the file is written only after the preview. Run quickstart VS-5.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Accessibility, platform conventions, privacy guarantees, executable boundaries, performance evidence, preset sign-off, and final gates.

- [ ] T104 [P] Accessibility pass adding labels, roles, values, and reading order on every custom control (FR-070, SC-009) — `Packages/MainScreenUI/Sources/`, `Packages/CutterLibraryModalUI/Sources/`
- [ ] T105 [P] Honour VoiceOver, Increase Contrast, Reduce Motion, and full keyboard access; verify both primary workflows without a pointing device (FR-071, SC-009) — `App/Sources/CNCswiftApp/`
- [ ] T106 [P] Implement menu-bar conventions, standard shortcuts, window restoration, and settings (FR-072) — `App/Sources/CNCswiftApp/Menus.swift`
- [ ] T107 [P] Offline audit asserting no networking import or API and recording the network-monitor result for a full session (FR-074, SC-010) — `App/Sources/CNCswiftApp/`, `Scripts/ci.sh`
- [ ] T108 [P] Hardware-boundary guard test failing if any serial, USB, or machine-control surface exists outside an explicitly empty allow-list (FR-030, C3) — `Packages/CNCPipeline/Tests/HardwareBoundaryTests.swift`
- [ ] T109 [P] Dialect-purity test failing if GRBL tokens or limits appear outside the profile and emitter (FR-015, FR-016, FR-017) — `Packages/CNCGCode/Tests/DialectPurityTests.swift`
- [ ] T110 [P] File-write-boundary test failing if any package other than `CNCGCode` and `CNCPipeline` can reach a file-writing API (FR-027, C2, C3) — `Packages/CNCGCode/Tests/WriteBoundaryTests.swift`
- [ ] T111 [P] Record cutting-experience review sign-off for the four preset bands, or keep `Fixtures/materials/README.md` marked provisional and block treating it as certified cutting data (research D11) — `Fixtures/materials/README.md`
- [ ] T112 [P] Benchmark on a 200,000-triangle fixture: decode plus generation under five minutes and preview within five seconds for all five fixtures in the current reference set (SC-001, SC-012) — `Fixtures/stl/`, `Packages/CNCGeometry/Sources/`
- [ ] T113 [P] Record SC-006 and SC-009 validation evidence from quickstart scenarios, including timed empty-library first-file and keyboard-only completion results (SC-006, SC-009) — `specs/001-stl-to-gcode/checklists/requirements.md`
- [ ] T114 Run all ten quickstart validation scenarios (VS-1 through VS-10) and record pass/fail evidence (SC-001 through SC-013) — `specs/001-stl-to-gcode/quickstart.md`
- [ ] T115 Confirm the first bundle build is ad-hoc signed and sandboxed: run `codesign -dvv .build/CNCswift.app` and `codesign -d --entitlements :- .build/CNCswift.app`, assert `Signature=adhoc` plus the sandbox entitlement with only the required file access, then `open .build/CNCswift.app` and verify user-selected file access; fix launch failures without dropping the entitlement (FR-073, FR-075, FR-076, constitution v4.3.0) — `Scripts/make-app.sh`, `App/Resources/CNCswift.entitlements`
- [ ] T116 [P] Add DocC comments to every public declaration across all sixteen packages, covering preconditions, thrown errors, and concurrency expectations; add a gate that fails when a `public` declaration lacks an immediately preceding DocC comment — `Packages/*/Sources/**/*.swift`, `Scripts/ci.sh`
- [ ] T117 Final gates: format lint clean, zero build warnings, all package tests green, and DocC gate green through `Scripts/ci.sh` — `Scripts/ci.sh`
- [ ] T118 Commit after each logical group in small pull requests that state the principles touched; never merge with failing or disabled tests or skipped concurrency checks (constitution, Development Workflow) — `.github/PULL_REQUEST_TEMPLATE.md`

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: depends on Setup; blocks all three stories.
- **US1 (Phase 3)**: depends on Foundational, which now includes the cutter store and seeded cutter fixture. Does not depend on US2 or US3; T052 uses a test confirmation and T040 reads a stored cutter while building the material in memory.
- **US2 (Phase 4)**: depends on Foundational; load/save and the change stream are already foundational, so US2 adds migration and the modal. T079 and T086 integrate with the US1 view model, so schedule them after T073.
- **US3 (Phase 5)**: depends on Foundational; T102 and T103 integrate with the US1 pipeline, so schedule them after T067 and T068. T094 is the write-gate test and must precede T103.
- **Polish (Phase 6)**: depends on the stories being hardened; T114 and T117 are the final gates.

### User story dependencies

- **US1 (P1)**: uses the cutter type, cutter store, and `Material` from Foundational, not the material store UI or modal. Its independent test loads a stored cutter from the seeded fixture.
- **US2 (P2)**: independently testable against fixtures and an injected file system. Only the deletion contract (T079) and selection subscription (T086) touch US1.
- **US3 (P3)**: independently testable from a fixture `ParsedProgram`. Only T102 and T103 touch the US1 pipeline.

### Within each user story

Tests are written first and must fail for the right reason. Value types precede services, services precede orchestration, and core work precedes integration. The cross-story integration points are T079/T086 (US2 → US1) and T102/T103 (US3 → US1).

### Parallel opportunities

- Phase 1: T002–T011 touch different files and can run together once T001 defines the workspace.
- Phase 2: T012–T025 are independent test files; T026–T035 are independent implementation files; T038 and T039 are fixture-only. T036 and T037 intentionally touch different store files and can run after T032.
- Phase 3: T040–T056 are independent test files across six packages; T057–T066 and T069–T073 are independent implementation files. T067, T068, and T075 integrate the stages and must come last.
- Phase 4: T076–T080 are independent test files; T082–T085 and T087 are independent implementation files. T086 follows T073.
- Phase 5: T089–T095 are independent test files; T096–T101 are independent implementation files. T102 follows T067 and T103 follows T094.
- Phase 6: T104–T113 and T116 touch different files and can run together.

```bash
# Phase 3 test wave (different packages, no shared state)
Task: "Golden emitter test in Packages/CNCGCode/Tests/EmitterTests.swift"
Task: "Validation rule tests in Packages/CNCValidation/Tests/RuleTests.swift"
Task: "Planner tests in Packages/CNCToolpath/Tests/PlannerTests.swift"
Task: "Library-to-generation contract test in Packages/CNCPipeline/Tests/GenerationContractTests.swift"
```

```bash
# Phase 2 types wave (different packages)
Task: "Profile data in Packages/CNCMachineProfile/Sources/TTC450Pro.swift"
Task: "Cutter model in Packages/CNCCutters/Sources/"
Task: "Material presets in Packages/CNCMaterials/Sources/Presets.swift"
Task: "Storage primitives in Packages/CNCStorage/Sources/"
```

```bash
# Phase 5 simulation test wave
Task: "Z-map tests in Packages/CNCSimulation/Tests/ZMapTests.swift"
Task: "Preview-mesh tests in Packages/CNCSimulation/Tests/PreviewMeshTests.swift"
Task: "Commit-gate test in Packages/CNCPipeline/Tests/CommitTests.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup.
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories).
3. Complete Phase 3 alone: a verified `.nc` from an STL with a stored cutter and an in-memory material, written only through explicit commit.
4. **STOP and VALIDATE** with quickstart VS-1, VS-2, VS-3, VS-4, and VS-9.
5. Only then add US2, US3, and polish.

### Incremental Delivery

1. Setup + Foundational → foundation ready, including the persisted cutter store and a seeded cutter.
2. US1 → first valid file (MVP) from a stored cutter; materials still supplied in code.
3. US2 → migrations and the modal; cutter edits reach the next file without relaunch.
4. US3 → the user sees the removal preview before committing.
5. Polish → accessibility, privacy, performance, sign-off, and final gates.

### Parallel Team Strategy

After Foundational, one developer can take US1, one US2, and one US3. The only coordination points are T079/T086 (store stream into the US1 view model) and T102/T103 (real simulator and hardened commit gate replacing the US1 stub).

---

## Requirement Coverage

Every requirement is assigned to at least one task.

| Requirement | Tasks |
|---|---|
| FR-001, FR-002, FR-003, FR-004 | T009, T014, T028 |
| FR-005, FR-006 | T049, T065, T072 |
| FR-007, FR-009, FR-012 | T013, T027, T040, T057, T069, T072 |
| FR-008, FR-010, FR-011 | T049, T065, T071 |
| FR-013, FR-014, FR-015, FR-016 | T012, T026, T109 |
| FR-017, FR-018 | T012, T026, T043, T044, T045, T057, T059, T109 |
| FR-019, FR-020, FR-021 | T040, T047, T057 |
| FR-022, FR-023, FR-024, FR-025 | T012, T017, T041, T043, T047, T049, T058, T071 |
| FR-026, FR-027, FR-028, FR-029 | T040, T042, T045, T046, T047, T052, T057, T059, T060, T068, T074 |
| FR-030, FR-031 | T012, T026, T044, T047, T108 |
| FR-032, FR-033, FR-034, FR-035, FR-036 | T048, T062, T063, T064 |
| FR-037, FR-038, FR-039, FR-041 | T013, T027, T048, T049, T050, T056, T064, T065 |
| FR-040 | T017, T048, T055, T056, T071, T073 |
| FR-042, FR-044, FR-045, FR-046, FR-047, FR-048 | T015, T024, T029, T077, T083, T084 |
| FR-043, FR-050 | T024, T054, T070 |
| FR-049 | T049, T065, T073 |
| FR-051, FR-052, FR-053, FR-054 | T020, T022, T023, T036, T076, T081, T088 |
| FR-055, FR-056, FR-057 | T002, T069, T071, T080, T082, T087 |
| FR-058, FR-059, FR-060 | T021, T025, T037, T079, T085, T086 |
| FR-061, FR-062, FR-063 | T089, T096, T099, T100 |
| FR-064, FR-065, FR-066 | T091, T092, T093, T098, T101, T102, T103 |
| FR-067, FR-068, FR-069 | T014, T018, T019, T033, T034, T053, T073, T092 |
| FR-070, FR-071, FR-072 | T087, T100, T104, T105, T106 |
| FR-073, FR-074, FR-075, FR-076 | T006, T007, T107, T115 |
| FR-077, FR-078 | T016, T030, T039, T051, T066, T071, T111 |
| FR-079, FR-080 | T017, T031, T054, T071 |
| FR-081 | T040, T041, T054, T057 |
| FR-082 | T043, T047, T057 |
| SC-001 | T112, T114 |
| SC-002, SC-003 | T040, T047, T074, T114 |
| SC-004 | T014, T015, T016, T049, T050, T114 |
| SC-005 | T042, T114 |
| SC-006 | T078, T113, T114 |
| SC-007 | T054, T079, T114 |
| SC-008 | T076, T088, T114 |
| SC-009 | T105, T113, T114 |
| SC-010 | T107, T114 |
| SC-011 | T045, T052, T053, T094, T103, T114 |
| SC-012 | T095, T112, T114 |
| SC-013 | T017, T054, T071, T114 |

---

## Notes

- `[P]` means different files and no dependency within the same wave. Do not mark two tasks `[P]` if they edit the same file.
- Every task names its file so no task reads "make it work".
- The commit gate follows clarification Q6 and `contracts/toolpath-api.md`: `run` prepares the program and preview; `commit` writes after explicit confirmation. Do not implement US1 acceptance scenario 1 literally until `spec.md` is reconciled.
- The rapid ceiling is a ratified controller-setting requirement in constitution v4.1.0 and retained through v4.3.0; T012, T041, T049, T058, and T071 implement it.
- SPM/CLT bundles are ad-hoc signed with `/usr/bin/codesign --sign -` under constitution v4.3.0; the sandbox entitlement is mandatory, and T006/T115 verify signing and entitlement configuration without dropping it.
- The five STL fixtures are the reference model set for SC-003 and SC-012; adding or removing one requires an amendment.
- The four preset band values in T030/T039 are provisional engineering guidance (research D11); T111 records sign-off before they are treated as certified production data.
- The feature branch is declared in `spec.md` but does not exist in git yet; create `001-stl-to-gcode` before the first implementation commit.
- Commit after each logical group, keep each pull request small, and run `Scripts/ci.sh` before calling work done.
