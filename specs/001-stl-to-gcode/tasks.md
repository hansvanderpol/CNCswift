/spe# Tasks: STL to Machine-Ready G-code

**Feature**: `001-stl-to-gcode` | **Branch**: `001-stl-to-gcode` | **Date**: 2026-11-16

**Input**: [plan.md](./plan.md), [spec.md](./spec.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [research.md](./research.md)

**Tests**: Required. Constitution Principle III makes tests non-negotiable: every behaviour task below has a preceding test task that must fail for the right reason before the implementation exists.

## Format

`- [ ] TNNN [P] [USn] Description (FR-xxx) — path`

- `[P]` = can run in parallel with other `[P]` tasks in the same phase (different files, no shared state).
- `[USn]` = the user story the task serves; setup, foundational, and polish tasks carry no story label.
- `FR-xxx` = the requirement the task satisfies, so coverage is checkable.
- Every task names a concrete path.

---

## Phase 1: Setup

**Purpose**: Create the workspace, tooling scripts, and bundle assembly. No behaviour.

- [ ] T001 Create the root `Package.swift` aggregating all packages and the `CNCswiftApp` executable — `Package.swift`
- [ ] T002 Add package skeletons with empty targets and test targets for all eleven packages — `Packages/*/Package.swift`
- [ ] T003 Add the app target skeleton with an empty `@main` scene — `App/Sources/CNCswiftApp/CNCswiftApp.swift`
- [ ] T004 Add `.swift-format` configuration at the repository root
- [ ] T005 Add `Scripts/ci.sh` resolving the Swift Testing plugin path dynamically, then running format lint, build, and test (research D2)
- [ ] T006 Add `Scripts/make-app.sh` assembling `CNCswift.app` with `Info.plist`, entitlements, and ad-hoc signing (FR-075, FR-076)
- [ ] T007 Add the sandbox entitlements file declaring app sandbox and user-selected file read-write only (FR-073)
- [ ] T008 Create the fixture directories and a fixtures README describing each reference file — `Fixtures/`
- [ ] T009 Add `.gitignore` for `.build/`, `.DS_Store`, and generated bundles
- [ ] T010 Record the verified build, test, format, and bundle commands in `AGENTS.md`

**Checkpoint**: `swift build` succeeds on empty targets and `Scripts/ci.sh` runs green.

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: Shared domain types every story depends on — profile, geometry, decode, cutter model, diagnostics, cancellation. No story-specific behaviour.

### Tests

- [ ] T011 [P] Tests for profile decoding, block order, limit invariants, and unknown-dialect rejection (FR-013, FR-014, FR-015, FR-016) — `Packages/CNCMachineProfile/Tests/`
- [ ] T012 [P] Tests for vector, bounds, and mesh invariants (FR-012) — `Packages/CNCGeometry/Tests/`
- [ ] T013 [P] Tests that BVH ray-cast heights match a brute-force scan on a reference mesh (FR-012) — `Packages/CNCGeometry/Tests/`
- [ ] T014 [P] Tests for ASCII and binary STL decoding, plus rejection of truncated, empty, degenerate, and non-manifold files (FR-001, FR-002, FR-003, FR-004) — `Packages/CNCSTL/Tests/`
- [ ] T015 [P] Tests for the cutter taxonomy, per-type field rejection, and every entry-validation rule (FR-044, FR-045, FR-046, FR-047, FR-048) — `Packages/CNCCutters/Tests/`
- [ ] T016 [P] Tests for structured logging categories and correlation identifiers (FR-067, FR-068) — `Packages/CNCDiagnostics/Tests/`
- [ ] T017 [P] Tests for cooperative cancellation and progress reporting semantics (FR-069) — `Packages/CNCDiagnostics/Tests/`

### Implementation

- [ ] T018 Implement the profile document type and the GRBL 1.1 TTC450 PRO profile data (FR-013, FR-014, FR-015, FR-016, FR-017, FR-018, FR-025) — `Packages/CNCMachineProfile/Sources/`
- [ ] T019 Implement vectors, bounds, mesh storage, and the BVH with ray-cast height queries (FR-012) — `Packages/CNCGeometry/Sources/`
- [ ] T020 Implement content-based ASCII/binary STL detection and decoding with defect reporting (FR-001, FR-002, FR-003) — `Packages/CNCSTL/Sources/`
- [ ] T021 Implement the explicit model-to-machine transform with declared origin (FR-007, FR-009, FR-012) — `Packages/CNCGeometry/Sources/Transform.swift`
- [ ] T022 Implement the cutter type hierarchy and entry validation, rejecting another type's fields (FR-044, FR-045, FR-046, FR-047, FR-048) — `Packages/CNCCutters/Sources/`
- [ ] T023 Implement typed stage errors with correlation identifiers and per-module `os.Logger` categories (FR-067, FR-068) — `Packages/CNCDiagnostics/Sources/`
- [ ] T024 Implement the progress sink and cancellation helper (FR-069) — `Packages/CNCDiagnostics/Sources/Cancellation.swift`
- [ ] T025 Commit reference fixtures: ASCII and binary STL, one corrupt, one empty, one non-manifold (FR-003) — `Fixtures/stl/`

**Checkpoint**: Foundational tests pass; no UI or pipeline behaviour exists yet.

---

## Phase 3: User Story 1 — Generate a validated G-code file (Priority: P1)

**Goal**: Decode an STL, plan roughing plus raster finishing, render a deterministic `.nc`, validate it independently, and write it atomically — with the two input panels needed to drive it.

**Independent Test**: With a cutter constructed in memory, generate from `Fixtures/stl/relief-demo-binary.stl` and verify the start and stop blocks, the 80-character limit, envelope containment, and determinism (quickstart VS-1, VS-2, VS-4).

### Tests

- [ ] T026 [P] [US1] Golden-file test for the header, start block, stop block, and three-decimal formatting (FR-019, FR-020, FR-021, FR-029) — `Packages/CNCGCode/Tests/`
- [ ] T027 [P] [US1] Determinism test: two renders differ only in the `generated` header line (FR-028) — `Packages/CNCGCode/Tests/`
- [ ] T028 [P] [US1] Line-length test: every rendered line is at most 80 characters, and an over-long case throws (D8) — `Packages/CNCGCode/Tests/`
- [ ] T029 [P] [US1] Parser tests for the GRBL 1.1 subset, unknown words, and modal-state tracking (FR-026) — `Packages/CNCValidation/Tests/`
- [ ] T030 [P] [US1] Rule tests: envelope, feed ceiling, rapid ceiling, spindle range, block order, `M5` before origin, `M30` last (FR-022, FR-023, FR-024, FR-025, FR-026) — `Packages/CNCValidation/Tests/`
- [ ] T031 [P] [US1] Planner tests: layer depth bound, finishing allowance, stepover bound, footprint restriction, rapids above material (FR-032, FR-033, FR-034, FR-035, FR-038, FR-039) — `Packages/CNCToolpath/Tests/`
- [ ] T032 [P] [US1] Preflight rejection tests: oversize stock, model outside stock, missing attribute, feature smaller than cutter, unconfirmed units (FR-005, FR-010, FR-011, FR-037, FR-041, FR-049) — `Packages/CNCToolpath/Tests/`
- [ ] T033 [P] [US1] Writer tests: atomic replace, no partial file on failure, no file on cancellation (FR-027, SC-011) — `Packages/CNCValidation/Tests/` (uses an injected file system)
- [ ] T034 [P] [US1] Orchestration test covering decode to written file, including cancellation mid-plan (FR-069) — `Packages/CNCToolpath/Tests/PipelineTests.swift`

### Implementation

- [ ] T035 [US1] Implement roughing layer planning down to the finishing allowance (FR-032, FR-033, FR-034) — `Packages/CNCToolpath/Sources/RoughingPlanner.swift`
- [ ] T036 [US1] Implement finishing raster planning with drop-cutter correction per cutter type (FR-032, FR-035, FR-036) — `Packages/CNCToolpath/Sources/FinishingPlanner.swift`
- [ ] T037 [US1] Implement clearance-height rapid sequencing between passes (FR-039) — `Packages/CNCToolpath/Sources/MoveSequencer.swift`
- [ ] T038 [US1] Implement footprint restriction to the model plus one cutter radius (FR-038) — `Packages/CNCToolpath/Sources/Footprint.swift`
- [ ] T039 [US1] Implement preflight checks and suggested-but-unconfirmed job settings (FR-037, FR-041, FR-049) — `Packages/CNCToolpath/Sources/Preflight.swift`
- [ ] T040 [US1] Implement the emitter: header record, profile blocks, invariant number formatting, 80-character guard (FR-019, FR-020, FR-021, FR-022, FR-029) — `Packages/CNCGCode/Sources/Emitter.swift`
- [ ] T041 [US1] Implement the header builder with cutter attributes, profile version, settings, units, origin, and scale (FR-029, FR-006, FR-007) — `Packages/CNCGCode/Sources/GenerationRecord.swift`
- [ ] T042 [US1] Implement the independent GRBL 1.1 line parser (FR-026, D7) — `Packages/CNCValidation/Sources/Parser.swift`
- [ ] T043 [US1] Implement semantic validation rules and the findings report (FR-022 to FR-026) — `Packages/CNCValidation/Sources/Rules.swift`
- [ ] T044 [US1] Implement the atomic `.nc` writer behind an injected file system (FR-027, FR-018) — `Packages/CNCGCode/Sources/FileWriter.swift`
- [ ] T045 [US1] Implement the `ToolpathService` actor orchestrating decode, plan, render, validate, simulate, and write, with cancellation (FR-069, D10) — `Packages/CNCToolpath/Sources/ToolpathService.swift`
- [ ] T046 [US1] Implement the cutter selection panel with read-only consumption of a cutter value (FR-055, FR-043) — `Packages/MainScreenUI/Sources/CutterPanel.swift`
- [ ] T047 [US1] Implement the material panel: stock dimensions, machining settings, and prefilled suggestions requiring confirmation (FR-008, FR-009, FR-010, FR-037) — `Packages/MainScreenUI/Sources/MaterialPanel.swift`
- [ ] T048 [US1] Implement the units and orientation confirmation step (FR-005, FR-006) — `Packages/MainScreenUI/Sources/ConfirmUnitsSheet.swift`
- [ ] T049 [US1] Implement the main screen view model with preflight messages and blocked states (FR-060, FR-049) — `Packages/MainScreenUI/Sources/MainScreenModel.swift`
- [ ] T050 [US1] Implement the generate action with progress and cancel affordances (FR-069) — `Packages/MainScreenUI/Sources/GenerateControls.swift`
- [ ] T051 [US1] Commit reviewed golden `.nc` files as production output (Development Workflow gate) — `Fixtures/gcode/`

**Checkpoint**: US1 generates a valid, deterministic `.nc` with a cutter built in code. Stop and run quickstart VS-1, VS-2, VS-3, VS-4.

---

## Phase 4: User Story 2 — Maintain the cutter library in a modal (Priority: P2)

**Goal**: Persist cutters in Application Support with a versioned schema, entry validation, and forward-only migrations, and present them in a separate modal module.

**Independent Test**: Create one cutter of each type in the modal, relaunch, and confirm identifiers and values survive; load a v1 fixture with a v2 build and confirm no loss (quickstart VS-7).

### Tests

- [ ] T052 [P] [US2] Round-trip and atomic-save tests against an injected file system, including backup creation (FR-051, FR-054) — `Packages/CNCCuttersStore/Tests/`
- [ ] T053 [P] [US2] Migration tests from v1 to v2 fixtures, including abort-without-loss on an unmigratable record (FR-052) — `Packages/CNCCuttersStore/Tests/`
- [ ] T054 [P] [US2] Newer-schema refusal and corrupt-file recovery tests, asserting the file is byte-identical after refusal (FR-053, FR-054) — `Packages/CNCCuttersStore/Tests/`
- [ ] T055 [P] [US2] Modal view-model tests: per-type forms, entry rejection, and clearing the main-screen selection on delete (FR-044, FR-048, FR-060) — `Packages/CutterLibraryModalUI/Tests/`
- [ ] T056 [P] [US2] Contract test proving a cutter edited in the modal produces the expected next generation (FR-050, SC-007) — `Packages/CutterLibraryModalUI/Tests/LibraryContractTests.swift`

### Implementation

- [ ] T057 [US2] Implement library load with the four outcomes: loaded, migrated, absent, refused, plus corrupt reporting (FR-051, FR-053, FR-054) — `Packages/CNCCuttersStore/Sources/LibraryStore.swift`
- [ ] T058 [US2] Implement atomic save with backup retention (FR-051) — `Packages/CNCCuttersStore/Sources/AtomicWrite.swift`
- [ ] T059 [US2] Implement the migration chain and v1/v2 fixtures (FR-052) — `Packages/CNCCuttersStore/Sources/Migrations.swift`
- [ ] T060 [US2] Implement the modal module entry point and cutter list (FR-056, FR-057) — `Packages/CutterLibraryModalUI/Sources/LibraryModal.swift`
- [ ] T061 [US2] Implement per-type editor forms that request only the type's dimensions (FR-045, FR-046) — `Packages/CutterLibraryModalUI/Sources/CutterEditor.swift`
- [ ] T062 [US2] Implement entry validation messaging at the field level (FR-048) — `Packages/CutterLibraryModalUI/Sources/CutterEditorModel.swift`
- [ ] T063 [US2] Implement delete and edit propagation that clears an invalid main-screen selection (FR-060, FR-058) — `Packages/CutterLibraryModalUI/Sources/LibraryModalModel.swift`
- [ ] T064 [US2] Implement the Cutter Library command and modal presentation from the main screen (FR-056, FR-072) — `App/Sources/CNCswiftApp/Commands.swift`
- [ ] T065 [US2] Wire the composition root so both modules are constructed independently (FR-057, FR-059) — `App/Sources/CNCswiftApp/Composition.swift`

**Checkpoint**: US1 and US2 both work independently; US1 can now use a stored cutter end to end.

---

## Phase 5: User Story 3 — 3D material-removal preview (Priority: P3)

**Goal**: Render the validated program as a material-removal preview in the third panel, with violations surfaced before writing.

**Independent Test**: Generate the reference job, confirm the preview shows the roughing cavity and finished surface, that rapids remove nothing, and that an artificially out-of-envelope move is highlighted (quickstart VS-5).

### Tests

- [ ] T066 [P] [US3] z-map tests: cutting moves lower the heightmap, rapids do not, and roughing plus finishing produce the expected depths (FR-061, FR-062, FR-063) — `Packages/CNCSimulation/Tests/`
- [ ] T067 [P] [US3] Preview-mesh tests: deterministic vertices and normals for a known heightmap (FR-061) — `Packages/CNCSimulation/Tests/MeshBuildTests.swift`
- [ ] T068 [P] [US3] Violation-surfacing tests: envelope and limit findings appear in the result before writing (FR-064) — `Packages/CNCSimulation/Tests/`
- [ ] T069 [P] [US3] Cancellation test: a cancelled simulation is reported as cancelled, not failed (FR-066) — `Packages/CNCSimulation/Tests/`

### Implementation

- [ ] T070 [US3] Implement the cutter-sweep z-map removal with stock-space resolution (FR-061, FR-062, FR-063) — `Packages/CNCSimulation/Sources/ZMap.swift`
- [ ] T071 [US3] Implement heightmap-to-mesh conversion with computed normals (FR-061) — `Packages/CNCSimulation/Sources/PreviewMesh.swift`
- [ ] T072 [US3] Implement violation collection from the validated program (FR-064, FR-065) — `Packages/CNCSimulation/Sources/Violations.swift`
- [ ] T073 [US3] Implement the RealityKit preview panel in the third slot, using `SwiftUI.Scene` qualification (FR-055, FR-061, research D3) — `Packages/MainScreenUI/Sources/SimulationPanel.swift`
- [ ] T074 [US3] Implement camera and keyboard navigation for the preview (FR-070) — `Packages/MainScreenUI/Sources/SimulationCamera.swift`
- [ ] T075 [US3] Implement simulation progress, cancel, and the violation list above the preview (FR-064, FR-066) — `Packages/MainScreenUI/Sources/SimulationModel.swift`

**Checkpoint**: All three stories work independently; the main screen has its three mandated panels.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T076 [P] Accessibility pass: labels, roles, values, and reading order on every custom control (FR-070) — `Packages/MainScreenUI/Sources/`, `Packages/CutterLibraryModalUI/Sources/`
- [ ] T077 [P] Honour VoiceOver, Increase Contrast, Reduce Motion, and full keyboard access (FR-071) — `App/Sources/CNCswiftApp/`
- [ ] T078 [P] Menu bar, standard shortcuts, and window restoration (FR-072) — `App/Sources/CNCswiftApp/Menus.swift`
- [ ] T079 [P] Privacy audit: assert no networking code exists and record the offline check (FR-074, SC-010) — `Packages/CNCDiagnostics/Sources/Privacy.swift`
- [ ] T080 Performance pass on a 200,000-triangle fixture: decode plus generation under 5 minutes, preview within 5 seconds (SC-001, SC-012) — `Packages/CNCGeometry/Sources/`
- [ ] T081 Add a test asserting no dialect literals appear outside the profile and emitter (FR-015) — `Packages/CNCGCode/Tests/DialectPurityTests.swift`
- [ ] T082 Run all eight quickstart scenarios and record pass/fail with evidence (SC-001 to SC-012) — `specs/001-stl-to-gcode/quickstart.md`
- [ ] T083 Confirm the sandboxed bundle launches and file access works through the open panel (FR-073) — `Scripts/make-app.sh`
- [ ] T084 Final gates: `swift format lint` clean, zero build warnings, all tests green via `Scripts/ci.sh`
- [ ] T085 Update `AGENTS.md` with the final command set and the repository-state correction (stale "no git repo" and "placeholder constitution" claims)

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: depends on Setup; blocks all three stories.
- **US1 (Phase 3)**: depends on Foundational.
- **US2 (Phase 4)**: depends on Foundational; integrates with US1 at T056 and T063.
- **US3 (Phase 5)**: depends on Foundational and on US1's validated-program output for realistic checks.
- **Polish (Phase 6)**: depends on the stories it hardens; T082 and T084 come last.

### Story dependencies

- **US1** needs the cutter *type* from Foundational but not the store or the modal. Its independent test constructs a cutter in memory, so US1 does not depend on US2.
- **US2** is independently testable against fixtures; it does not need US1 to run.
- **US3** consumes a `RenderedProgram`; tests supply fixture programs, so US3 does not strictly need US1 complete, though T082 exercises them together.

### Within each story

Tests precede implementation and must fail first. Within US1: planners before sequencing, sequencing before the emitter, parser before rules, then orchestration, then panels.

## Parallel Opportunities

Phase 2 tests T011–T017 are all `[P]`: different packages, different files. Phase 3 tests T026–T034 are `[P]` for the same reason. Phase 4 tests T052–T056 and Phase 5 tests T066–T069 are `[P]` likewise. Polish tasks T076–T081 are `[P]`.

```bash
# Phase 3 test wave, in parallel
Task: "Golden-file test for header and blocks in Packages/CNCGCode/Tests/"
Task: "Parser tests for the GRBL subset in Packages/CNCValidation/Tests/"
Task: "Planner tests for layers and stepover in Packages/CNCToolpath/Tests/"
Task: "Preflight rejection tests in Packages/CNCToolpath/Tests/"
```

## Implementation Strategy

### MVP first

1. Phase 1 and Phase 2.
2. Phase 3 alone delivers the product's core: a verified `.nc` from an STL.
3. Stop and run quickstart VS-1 to VS-4 before continuing.

### Incremental delivery

Add US2 (persistence and modal), then US3 (preview), then polish. Each phase leaves a working app: after US1 the app generates files with cutters built in code; after US2 cutters come from disk; after US3 the user can see the carve before committing.

### Risk-first ordering

The three highest-risk items are front-loaded: the BVH and drop-cutter queries (T013, T019, T036), the independent validator (T029, T042, T043), and the 80-character emitter rule (T028, T040). Each has a test before implementation.

## Notes

- `[P]` means no dependency on another task in the same wave.
- Every task names its file, so no task is "make it work".
- Do not begin implementation before this file exists (constitution, Development Workflow).
- Commit after each logical group; keep pull requests small and name the principles touched.
