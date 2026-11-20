# Graph Report - CNCswift  (2026-11-20)

## Corpus Check
- 259 files · ~145,322 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 18 file(s) not represented in the graph (top: .nc 6, .stl 5, (none) 3)

## Summary
- 2524 nodes · 5543 edges · 179 communities (123 shown, 56 thin omitted)
- Extraction: 90% EXTRACTED · 10% INFERRED · 0% AMBIGUOUS · INFERRED: 562 edges (avg confidence: 0.86)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `2a034c41`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Contract: Cutter Library
- Skill: Test Script (Grafana k6)
- steps
- common.sh
- Tasks: [FEATURE NAME]
- EffectiveCuttingValues
- speckit.analyze.md
- Technical Design - [Feature Title]
- Functional Requirements
- Phase 1 Data Model: STL to Machine-Ready G-code
- End-to-end validation scenarios
- Phase 0 Research: STL to Machine-Ready G-code
- Execution Steps
- Implementation Plan: STL to Machine-Ready G-code
- AGENTS.md
- DDE-999 — Customer Support Ticket
- Core Principles
- Feature Specification: [FEATURE NAME]
- Contract: Stage Boundaries
- Skill: Data Definition
- Acceptance Criterias
- Testing
- speckit.plan.md
- speckit.specify.md
- speckit.tasks.md
- Skill: Technical Design
- Test Scenario - [Feature Title]
- UC-999 — Create Customer Support Ticket
- UC-999 — [Use Case Name]
- Core Principles
- DDE-999 — [Data Model Name]
- Skill: Test Scenario
- Skill: User Story
- Implementation Plan: [FEATURE]
- Contract: Material Library
- speckit.checklist.md
- US-999 - [User Story Name]
- speckit.clarify.md
- speckit.implement.md
- Skill: Entity Relationship Diagram (ERD)
- Skill: Flowchart
- Skill: Mindmap
- Skill: Sequence Diagram
- Skill: State Diagram
- Skill: Use Case
- Skill: User Journey
- speckit.constitution.md
- Context7
- checklist-template.md
- scope/SKILL.md
- STLDecoderTests.swift
- Contract: G-code Output File
- MaterialBand
- CommitTests.swift
- PackageDescription
- FakeFileSystem
- Reference Fixtures
- ci.sh
- make-app.sh
- MeshDocument
- CommitTests.swift
- CorrelationID
- MainScreen
- CNCMachineProfile
- .date
- MaterialPanel
- ValidationReport
- LoadOutcomeTests.swift
- CutterValidationError
- Error
- SimulationResult
- Cutter
- Finding
- Material
- BoundaryTests.swift
- ProgressSink
- Quickstart: STL to Machine-Ready G-code
- AccessibilityText
- MainScreenModelTests.swift
- LibraryModal
- Material Fixtures
- Codable
- GRBLParser
- View
- MaterialLibraryLoadOutcome
- MachineProfile
- Equatable
- AppComposition
- .job
- MaterialStoreTests.swift
- .moves
- .save
- check-docc.py
- CutterLibraryStore
- ResolutionTests.swift
- Vec3
- CutterLibraryLoadOutcome
- FakeFileSystem
- DiagnosticLogger
- LibraryChange
- SimulationPanel
- Contract: Machine Profile
- PreviewMeshTests.swift
- .lines
- SimulationPanel.swift
- FakeError
- quickstart.md
- .job
- Tasks: STL to Machine-Ready G-code
- CameraNavigation
- DiagnosticCategory
- MainScreenGenerationStatus
- .render
- offline-audit.sh
- RenderingError
- FeatureReport
- ContractFileSystem
- Foundation
- Specification Quality Checklist: STL to Machine-Ready G-code
- FileSystem
- GenerationBlocker
- String
- SimulationViolations
- Sendable
- SimulationViolation
- update-golden.sh
- ResolutionOutcome
- PipelineError
- SensitiveValue
- PULL_REQUEST_TEMPLATE.md
- Accessibility support record — 001-stl-to-gcode
- JobSuggestion
- DialectPurityTests.swift
- Dependencies & Execution Order
- RapidHeaderTests.swift
- WriteBoundaryTests.swift
- HardwareBoundaryTests.swift
- isRapid

## God Nodes (most connected - your core abstractions)
1. `Vec3` - 84 edges
2. `MachineProfile` - 71 edges
3. `Testing` - 69 edges
4. `MainScreenModel` - 69 edges
5. `Cutter` - 64 edges
6. `ProgressSink` - 50 edges
7. `JobSettings` - 49 edges
8. `CNCMachineProfile` - 49 edges
9. `CNCCutters` - 47 edges
10. `CutterID` - 44 edges

## Surprising Connections (you probably didn't know these)
- `Notes` --references--> `DiagnosticLogger`  [INFERRED]
  specs/001-stl-to-gcode/tasks.md → Packages/CNCDiagnostics/Sources/Diagnostics.swift
- `Task-shaping notes for `/speckit.tasks`` --references--> `WriteConfirmation`  [INFERRED]
  specs/001-stl-to-gcode/plan.md → Packages/CNCPipeline/Sources/Protocols.swift
- `Post-Design Constitution Re-check` --references--> `DiagnosticLogger`  [INFERRED]
  specs/001-stl-to-gcode/plan.md → Packages/CNCDiagnostics/Sources/Diagnostics.swift
- `Implementation and gates` --references--> `SensitiveValue`  [INFERRED]
  specs/001-stl-to-gcode/tasks.md → Packages/CNCDiagnostics/Sources/Redaction.swift
- `Tests for CT1 (write first; they must fail)` --references--> `SensitiveValue`  [INFERRED]
  specs/001-stl-to-gcode/tasks.md → Packages/CNCDiagnostics/Sources/Redaction.swift

## Import Cycles
- None detected.

## Communities (179 total, 56 thin omitted)

### Community 0 - "Contract: Cutter Library"
Cohesion: 0.18
Nodes (11): Change notification (FR-060, research D14), Contract: Cutter Library, Cross-module import rule, Document schema (v1), Entry validation, Generation preflight (FR-033, FR-049), Migration contract, Read-only consumption rules (+3 more)

### Community 1 - "Skill: Test Script (Grafana k6)"
Cohesion: 0.07
Nodes (25): API_KEY, BASE_URL, ENDPOINT, headers(), Construct cheat sheet, Faithfulness, k6 Patterns & Reference Structure, Schema from the OpenAPI contract (+17 more)

### Community 2 - "steps"
Cohesion: 0.06
Nodes (30): args, inputs, integration, spec, default, prompt, type, any (+22 more)

### Community 3 - "common.sh"
Cohesion: 0.11
Nodes (30): check-prerequisites.sh script, check_dir(), check_file(), find_specify_root(), format_speckit_command(), get_current_branch(), get_feature_paths(), get_invoke_separator() (+22 more)

### Community 4 - "Tasks: [FEATURE NAME]"
Cohesion: 0.07
Nodes (26): Dependencies & Execution Order, Format: `[ID] [P?] [Story] Description`, Implementation for User Story 1, Implementation for User Story 2, Implementation for User Story 3, Implementation Strategy, Incremental Delivery, MVP First (User Story 1 Only) (+18 more)

### Community 5 - "EffectiveCuttingValues"
Cohesion: 0.17
Nodes (10): BandConflict, BandKind, feed, spindle, EffectiveCuttingValues, EffectiveValueSource, cutterPrefill, nearestBound (+2 more)

### Community 6 - "speckit.analyze.md"
Cohesion: 0.08
Nodes (25): 1. Initialize Analysis Context, 2. Load Artifacts (Progressive Disclosure), 3. Build Semantic Models, 4. Detection Passes (Token-Efficient Analysis), 5. Severity Assignment, 6. Produce Compact Analysis Report, 7. Provide Next Actions, 8. Offer Remediation (+17 more)

### Community 7 - "Technical Design - [Feature Title]"
Cohesion: 0.08
Nodes (24): API Design, `/api/v1/foo/bar`, Basic Flow, Basic Logic, Changelog, Database Design, Entry Point 1 (e.g. API /api/v1/foo/bar), Failure & Retry Registry (+16 more)

### Community 8 - "Functional Requirements"
Cohesion: 0.08
Nodes (25): Assumptions, Carving material, Clarifications, Cutter library, Diagnostics, accessibility, and privacy, Edge Cases, Feature Specification: STL to Machine-Ready G-code, Functional Requirements (+17 more)

### Community 9 - "Phase 1 Data Model: STL to Machine-Ready G-code"
Cohesion: 0.11
Nodes (19): Built-in presets (shipped, read-only), Cutter, CutterLibrary, EffectiveCuttingValues, GCodeProgram, GenerationRecord (file header), Job state transitions, JobSettings (+11 more)

### Community 10 - "End-to-end validation scenarios"
Cohesion: 0.18
Nodes (11): End-to-end validation scenarios, VS-10 — Feature smaller than the cutter (FR-041), VS-1 — Happy path: STL to `.nc` (SC-001, SC-002, SC-003, SC-013), VS-2 — Determinism (SC-005), VS-3 — Rejection, not repair (SC-004), VS-4 — Start and stop block integrity (SC-003), VS-5 — 3D preview (SC-012), VS-6 — Cutter edit propagates (SC-007) (+3 more)

### Community 11 - "Phase 0 Research: STL to Machine-Ready G-code"
Cohesion: 0.12
Nodes (17): D10. Concurrency: one generation actor, cancellable progress streams, D11. Material bands and effective-value resolution, D12. Rapid rate: controller settings, not program text, D13. Orchestration boundary: a `CNCPipeline` package, D14. Cutter-deletion propagation without shared mutable state, D1. Build: SPM workspace plus a bundle script, no Xcode project, D2. Testing: Swift Testing with an explicit macro-plugin path, D3. 3D preview: RealityKit, not SceneKit (+9 more)

### Community 12 - "Execution Steps"
Cohesion: 0.12
Nodes (15): 1. Initialize Convergence Context, 2. Load Artifacts (Progressive Disclosure), 3. Build the Intent Inventory, 4. Assess the Codebase and Classify Findings, 5. Assign Severity, 6. Present the In-Session Findings Summary, 7. Append Convergence Tasks (or report converged), 8. Provide Next Actions (Handoff) (+7 more)

### Community 13 - "Implementation Plan: STL to Machine-Ready G-code"
Cohesion: 0.13
Nodes (15): Analysis follow-up: insufficient cutter margin (T120), Complexity Tracking, Constitution Check, Design Flow, Documentation (this feature), Implementation Plan: STL to Machine-Ready G-code, Package dependency graph, Package rationale (Principle II) (+7 more)

### Community 14 - "AGENTS.md"
Cohesion: 0.09
Nodes (17): Agent behaviour, Build, lint, and test commands (verified on this machine), Coding standards, Constitution, Documents and diagrams, Feature state and layout, Generated files, graphify (+9 more)

### Community 15 - "DDE-999 — Customer Support Ticket"
Cohesion: 0.15
Nodes (12): Attachment, Category, Changelog, Customer, DDE-999 — Customer Support Ticket, Entity Definitions, Entity Relationship Diagrams, Entity Summary (+4 more)

### Community 16 - "Core Principles"
Cohesion: 0.15
Nodes (12): CNCswift Constitution, Core Principles, Development Workflow and Quality Gates, Governance, I. Swift 6 Language Mode and Strict Concurrency (NON-NEGOTIABLE), II. Modular Package-First Architecture, III. Test-First (NON-NEGOTIABLE), IV. Native macOS Fidelity and Accessibility (+4 more)

### Community 17 - "Feature Specification: [FEATURE NAME]"
Cohesion: 0.15
Nodes (12): Assumptions, Edge Cases, Feature Specification: [FEATURE NAME], Functional Requirements, Key Entities *(include if feature involves data)*, Measurable Outcomes, Requirements *(mandatory)*, Success Criteria *(mandatory)* (+4 more)

### Community 18 - "Contract: Stage Boundaries"
Cohesion: 0.14
Nodes (14): Commit, Contract: Stage Boundaries, Decode, Dependency direction, Error shape, Material resolution, Orchestration, Persistence (+6 more)

### Community 19 - "Skill: Data Definition"
Cohesion: 0.17
Nodes (11): Always (logical data model), Clarifying Question (mandatory, every prompt), ID / Prefix, If user chose Markdown + ERD (do in sequence), Input (strict), Output Path, Process, Purpose (+3 more)

### Community 20 - "Acceptance Criterias"
Cohesion: 0.17
Nodes (11): AC-999-001 - Successful Ticket Submission, AC-999-002 - Ticket Submitted with Attachments, AC-999-003 - High-Priority Category Auto-Assignment, AC-999-004 - Required Fields Validation, AC-999-005 - Invalid Attachment Rejected, AC-999-006 - Unauthenticated Access Blocked, AC-999-007 - System Unavailable, Acceptance Criterias (+3 more)

### Community 22 - "speckit.plan.md"
Cohesion: 0.18
Nodes (10): Completion Report, Done When, Key rules, Mandatory Post-Execution Hooks, Outline, Phase 0: Outline & Research, Phase 1: Design & Contracts, Phases (+2 more)

### Community 23 - "speckit.specify.md"
Cohesion: 0.18
Nodes (10): Completion Report, Done When, For AI Generation, Mandatory Post-Execution Hooks, Outline, Pre-Execution Checks, Quick Guidelines, Section Requirements (+2 more)

### Community 24 - "speckit.tasks.md"
Cohesion: 0.18
Nodes (10): Checklist Format (REQUIRED), Completion Report, Done When, Mandatory Post-Execution Hooks, Outline, Phase Structure, Pre-Execution Checks, Task Generation Rules (+2 more)

### Community 25 - "Skill: Technical Design"
Cohesion: 0.18
Nodes (10): Clarifying Questions (mandatory, before generating), Data Definition Input (when database design is involved), ID / Prefix, Input (strict), Output Path, Process, Purpose, Sequencing (+2 more)

### Community 26 - "Test Scenario - [Feature Title]"
Cohesion: 0.18
Nodes (10): Changelog, Coverage Matrix, Scenario 1: [Scenario Name], Scenario N: [Scenario Name], Source Requirement, TC-999-001 - [Test Case Title], TC-999-00N - [Test Case Title], Test Basis & Assumptions (+2 more)

### Community 27 - "UC-999 — Create Customer Support Ticket"
Cohesion: 0.18
Nodes (10): Alternative Flows, Assumptions, Business Rules, Changelog, Exceptions, Normal Flow, Overview, Priority (+2 more)

### Community 28 - "UC-999 — [Use Case Name]"
Cohesion: 0.18
Nodes (10): Alternative Flows, Assumptions, Business Rules, Changelog, Exceptions, Normal Flow, Overview, Priority (+2 more)

### Community 29 - "Core Principles"
Cohesion: 0.18
Nodes (10): Core Principles, Governance, [PRINCIPLE_1_NAME], [PRINCIPLE_2_NAME], [PRINCIPLE_3_NAME], [PRINCIPLE_4_NAME], [PRINCIPLE_5_NAME], [PROJECT_NAME] Constitution (+2 more)

### Community 30 - "DDE-999 — [Data Model Name]"
Cohesion: 0.20
Nodes (9): Changelog, DDE-999 — [Data Model Name], Entity Definitions, [Entity Name], Entity Relationship Diagrams, Entity Summary, Relationships, Scope (+1 more)

### Community 31 - "Skill: Test Scenario"
Cohesion: 0.20
Nodes (9): Clarifying Questions (mandatory, before generating), ID / Prefix, Input (strict), Output Path, Process, Purpose, Sequencing, Skill: Test Scenario (+1 more)

### Community 32 - "Skill: User Story"
Cohesion: 0.22
Nodes (8): Acceptance Criteria, ID Format, ID Format, Output Path, Process, Sequencing, Skill: User Story, Template & Example

### Community 33 - "Implementation Plan: [FEATURE]"
Cohesion: 0.22
Nodes (8): Complexity Tracking, Constitution Check, Documentation (this feature), Implementation Plan: [FEATURE], Project Structure, Source Code (repository root), Summary, Technical Context

### Community 34 - "Contract: Material Library"
Cohesion: 0.22
Nodes (8): Built-in presets, Contract: Material Library, Entry validation (FR-078), Interaction contract, Material record, Resolution (FR-079, FR-080), Storage, Tests this contract requires

### Community 35 - "speckit.checklist.md"
Cohesion: 0.25
Nodes (7): Anti-Examples: What NOT To Do, Checklist Purpose: "Unit Tests for English", Example Checklist Types & Sample Items, Execution Steps, Post-Execution Checks, Pre-Execution Checks, User Input

### Community 36 - "US-999 - [User Story Name]"
Cohesion: 0.25
Nodes (7): AC-999-001 - [Acceptance Criteria Name], AC-999-00N - [Acceptance Criteria Name], Acceptance Criterias, Changelog, Related Artifacts, US-999 - [User Story Name], User Story

### Community 37 - "speckit.clarify.md"
Cohesion: 0.29
Nodes (6): Completion Report, Done When, Mandatory Post-Execution Hooks, Outline, Pre-Execution Checks, User Input

### Community 38 - "speckit.implement.md"
Cohesion: 0.29
Nodes (6): Completion Report, Done When, Mandatory Post-Execution Hooks, Outline, Pre-Execution Checks, User Input

### Community 39 - "Skill: Entity Relationship Diagram (ERD)"
Cohesion: 0.29
Nodes (6): ID / Prefix, Mermaid Type, Output Path, Process, Sequencing, Skill: Entity Relationship Diagram (ERD)

### Community 40 - "Skill: Flowchart"
Cohesion: 0.29
Nodes (6): ID / Prefix, Mermaid Type, Output Path, Process, Sequencing, Skill: Flowchart

### Community 41 - "Skill: Mindmap"
Cohesion: 0.29
Nodes (6): ID / Prefix, Mermaid Type, Output Path, Process, Sequencing, Skill: Mindmap

### Community 42 - "Skill: Sequence Diagram"
Cohesion: 0.29
Nodes (6): ID / Prefix, Mermaid Type, Output Path, Process, Sequencing, Skill: Sequence Diagram

### Community 43 - "Skill: State Diagram"
Cohesion: 0.29
Nodes (6): ID / Prefix, Mermaid Type, Output Path, Process, Sequencing, Skill: State Diagram

### Community 44 - "Skill: Use Case"
Cohesion: 0.29
Nodes (6): ID Format, Output Path, Process, Sequencing, Skill: Use Case, Template & Example

### Community 45 - "Skill: User Journey"
Cohesion: 0.29
Nodes (6): ID / Prefix, Mermaid Type, Output Path, Process, Sequencing, Skill: User Journey

### Community 46 - "speckit.constitution.md"
Cohesion: 0.33
Nodes (5): Outline, Post-Execution Checks, Pre-Execution Checks, Scope Guard, User Input

### Community 47 - "Context7"
Cohesion: 0.50
Nodes (3): Context7, Install, Key Benefits

### Community 48 - "checklist-template.md"
Cohesion: 0.50
Nodes (3): [Category 1], [Category 2], Notes

### Community 51 - "STLDecoderTests.swift"
Cohesion: 0.28
Nodes (12): asciiAndBinaryFixturesDecodeToTheSameRelief(), decode(), denseFixtureDecodesAll200000Triangles(), emptyTruncatedAndCorruptInputsAreRejected(), fixtureURL(), nonManifoldAndDegenerateTrianglesAreRejected(), progressIsReportedFrom50000Triangles(), rejectionNamesTheFileAndDefect() (+4 more)

### Community 52 - "Contract: G-code Output File"
Cohesion: 0.22
Nodes (9): Body formatting, Contract: G-code Output File, Example fragment, Explicitly forbidden in output, File-level rules, Header, Output filename, Program body order (+1 more)

### Community 53 - "MaterialBand"
Cohesion: 0.24
Nodes (5): MaterialBand, MaterialOrigin, builtIn, user, MaterialValidator

### Community 54 - "CommitTests.swift"
Cohesion: 0.08
Nodes (5): storage, CancellationFileSystem, ContractFileSystem, FakeFileSystem, FakeFileSystem

### Community 56 - "FakeFileSystem"
Cohesion: 0.21
Nodes (9): corruptDocumentIsReported(), FakeFileSystem, missingDocumentLoadsAsAbsent(), newerSchemaIsRefusedAndFileIsByteIdentical(), olderSchemaMigratesForwardWithoutRecordLoss(), Payload, saveStampsTheCurrentSchemaVersion(), secondSaveKeepsThePreviousFileAsBackup() (+1 more)

### Community 57 - "Reference Fixtures"
Cohesion: 0.40
Nodes (4): Amendment rule, Other fixture directories, Reference Fixtures, Reference STL models (exactly five)

### Community 60 - "MeshDocument"
Cohesion: 0.05
Nodes (38): Golden G-code Output, Pipeline-level golden (T121–T124, C1), benchmarkDecodeAndGenerationFor200KTriangleFixture(), benchmarkPreviewForAllFiveReferenceModels(), BenchmarkSupport, generatedProgramFromAReferenceFixturePassesValidation(), committedGenerationGoldenMatchesPipelineOutput(), generateGoldenCandidateIntoReceivedDirectoryForReview() (+30 more)

### Community 62 - "CommitTests.swift"
Cohesion: 0.10
Nodes (32): WriteConfirmation, assertNoArtifacts(), blockedSimulationCannotBeCommitted(), cancelledSimulationCannotBeCommitted(), CommitFileSystem, CommitPlanner, CommitRenderer, CommitSimulator (+24 more)

### Community 64 - "CorrelationID"
Cohesion: 0.23
Nodes (9): os, CNCError, CorrelationID, .description, StageFailure, .userMessage, distinctFailuresReceiveDistinctCorrelationIDs(), loggerRecordSharesCorrelationIDAndCategory() (+1 more)

### Community 66 - "MainScreen"
Cohesion: 0.16
Nodes (7): GenerateControls, .progressValue, .statusLabel, .statusView, MainScreen, .body, .header

### Community 70 - "CNCMachineProfile"
Cohesion: 0.15
Nodes (13): CNCDiagnostics, CNCGCode, CNCGeometry, CNCMachineProfile, CNCMaterials, CNCPipeline, CNCSimulation, CNCSTL (+5 more)

### Community 76 - ".date"
Cohesion: 0.12
Nodes (22): GCodeEmitter, headerWeldsTheInjectedInstantRatherThanTodaysDate(), identicalInputsAndClockProduceByteIdenticalText(), twoRunsDifferOnlyOnTheGeneratedLine(), EmitterFixture, cuttingCoordinatesUseThreeDecimals(), hasThreeDecimals(), headerMatchesTheCommittedGoldenLayout() (+14 more)

### Community 77 - "MaterialPanel"
Cohesion: 0.14
Nodes (10): MaterialPanel, .conflicts, .effectiveValuesSection, .jobSettingsSection, .materialSection, .prefilledValues, .rapidRateSection, .rapidSetupDescription (+2 more)

### Community 78 - "ValidationReport"
Cohesion: 0.15
Nodes (6): Preparation, blocked, cancelled, ready, CancellationValidator, ValidationReport

### Community 79 - "LoadOutcomeTests.swift"
Cohesion: 0.11
Nodes (9): FakeFileSystem, corruptDocumentIsReportedWithPathAndOriginalBytesIntact(), cutter(), DocumentEnvelope, FakeError, missing, FakeFileSystem, LibraryDocument (+1 more)

### Community 80 - "CutterValidationError"
Cohesion: 0.07
Nodes (31): CutterValidationError, emptyName, feedOutOfRange, forbiddenField, invalidAngle, invalidFluteCount, missingField, nonPositive (+23 more)

### Community 81 - "Error"
Cohesion: 0.08
Nodes (25): FakeError, missing, write, FakeError, missing, FakeError, missing, FakeError (+17 more)

### Community 82 - "SimulationResult"
Cohesion: 0.17
Nodes (5): Heightmap, SimulationResult, SimulationSegment, SimulationViolation, ZMapSimulator

### Community 83 - "Cutter"
Cohesion: 0.16
Nodes (5): Cutter, .maxCuttingExtent, contractCutter(), modalCutterEditFlowsIntoTheNextHeaderWithoutRelaunch(), .selectedCutter

### Community 84 - "Finding"
Cohesion: 0.08
Nodes (22): GCodeLexer, GCodeWord, .canonical, .value, Finding, FindingSeverity, error, warning (+14 more)

### Community 85 - "Material"
Cohesion: 0.29
Nodes (5): Material, Presets, MaterialLibraryDocument, MaterialLibraryStoring, confirmedValues()

### Community 86 - "BoundaryTests.swift"
Cohesion: 0.33
Nodes (7): manifest(), noDomainPackageImportsSwiftUIOrRealityKit(), noStageDependsOnPipeline(), plannerDoesNotDependOnEmitterValidatorOrPipeline(), presentationModulesDoNotImportEachOther(), repositoryRoot(), validationDoesNotDependOnEmitter()

### Community 87 - "ProgressSink"
Cohesion: 0.10
Nodes (15): CancellationSource, .isCancelled, withCooperativeCancellation(), CooperativeOutcome, cancelled, completed, CooperativeWork, ProgressSink (+7 more)

### Community 88 - "Quickstart: STL to Machine-Ready G-code"
Cohesion: 0.22
Nodes (9): Documentation gate, Format check, Manual controller check, Prerequisites, Quickstart: STL to Machine-Ready G-code, Run, Setup, Test commands (+1 more)

### Community 89 - "AccessibilityText"
Cohesion: 0.14
Nodes (3): AccessibilityPriority, AccessibilityText, ContrastAwareSelection

### Community 91 - "MainScreenModelTests.swift"
Cohesion: 0.29
Nodes (11): CutterID, .description, .body, jobStrategyIsSuggestedButNotAppliedUntilConfirmed(), effectiveValues(), emptyCutterSelectionBlocksGeneration(), emptyMaterialOverlapBlocksGeneration(), suggestion() (+3 more)

### Community 93 - "Material Fixtures"
Cohesion: 0.29
Nodes (6): Amendment rule, Cutting-experience sign-off (task T111), Material Fixtures, Shipped preset bands, Status: PROVISIONAL, T111 decision record — 2026-11-20

### Community 94 - "Codable"
Cohesion: 0.06
Nodes (41): cutter(), DocumentEnvelope, identifierSurvivesEditSaveReloadAndMigration(), LibraryDocument, CutterPayload, cutters(), DocumentEnvelope, FakeFileSystem (+33 more)

### Community 95 - "GRBLParser"
Cohesion: 0.18
Nodes (10): GRBLParser, FindingKind, .prefix, .ruleIdentifier, unknown, unsupported, parsesBasicGRBLSubsetAndTracksModalState(), reportsLinesLongerThanProfileLimit() (+2 more)

### Community 107 - "View"
Cohesion: 0.23
Nodes (4): CNCswiftSettings, .body, CutterPanel, .body

### Community 113 - "MaterialLibraryLoadOutcome"
Cohesion: 0.18
Nodes (6): MaterialLibraryLoadOutcome, absent, corrupt, loaded, migrated, refused

### Community 114 - "MachineProfile"
Cohesion: 0.13
Nodes (10): MachineProfile, CancellationRenderer, JobSettings, StockBlank, Toolpath, ParsedProgram, .lines, Implementation for User Story 3 (+2 more)

### Community 115 - "Equatable"
Cohesion: 0.24
Nodes (7): WorkFailure, boom, .generatedAtHeaderValue, GenerationRecord, RenderedProgram, MaterialResolutionError, outsideIntersection

### Community 116 - "AppComposition"
Cohesion: 0.09
Nodes (7): AppComposition, .documentFileName, CancellationFlag, .body, JobSuggestionEngine, .body, .computedSuggestion

### Community 117 - ".job"
Cohesion: 0.08
Nodes (38): ToolpathPlanner, PlanningError, cutterTooShort, depthExceedsCuttingLength, envelopeExceeded, featureTooSmall, insufficientCutterMargin, invalidAllowance (+30 more)

### Community 118 - "MaterialStoreTests.swift"
Cohesion: 0.22
Nodes (11): CNCMaterialsStore, MaterialLibraryStore, aUserMaterialShadowingAPresetIsRejectedAtSave(), documentURL(), FakeFileSystem, MaterialDocument, missingDocumentLoadsAsAbsent(), newerSchemaIsRefusedAndTheDocumentIsLeftUntouched() (+3 more)

### Community 119 - ".moves"
Cohesion: 0.18
Nodes (8): FinishingPlanner, Footprint, MoveSequencer, Move, MoveMode, cut, rapid, RoughingPlanner

### Community 120 - ".save"
Cohesion: 0.36
Nodes (5): bufferedStreamDoesNotDropEventsPublishedBeforeConsumption(), changeStreamDeliversSavedDeletedAndReloadedInOrder(), cutter(), failedSaveDoesNotPublishASavedEvent(), savedValuesAreNotSharedMutableState()

### Community 121 - "check-docc.py"
Cohesion: 0.23
Nodes (5): check_file(), has_docc(), main(), swift_files(), Phase 6: Polish & Cross-Cutting Concerns

### Community 122 - "CutterLibraryStore"
Cohesion: 0.33
Nodes (5): CutterLibraryDocument, CutterLibraryStore, CutterLibraryCoordinator, emptyLibraryReachesAStoredValidCutterWithoutHelp(), modalEntryPointAndEditorRunWithoutTheMainScreen()

### Community 123 - "ResolutionTests.swift"
Cohesion: 0.36
Nodes (7): bandMaterial(), cutter(), cutterValueInsideIntersectionIsPrefilledButUnconfirmed(), cutterValueOutsideIntersectionUsesNearestBound(), emptyFeedOverlapNamesMaterialBandAndCeiling(), emptySpindleOverlapNamesMaterialBandAndFloor(), userChoiceInsideIntersectionIsConstructibleAndOutOfRangeIsNot()

### Community 124 - "Vec3"
Cohesion: 0.07
Nodes (22): AABB, BVH, Node, .bounds, branch, leaf, Mesh, .bounds (+14 more)

### Community 125 - "CutterLibraryLoadOutcome"
Cohesion: 0.18
Nodes (6): CutterLibraryLoadOutcome, absent, corrupt, loaded, migrated, refused

### Community 127 - "DiagnosticLogger"
Cohesion: 0.36
Nodes (7): DiagnosticLogger, DiagnosticLogRecord, loggerRedactsExplicitSensitivePayloads(), Implementation and gates, Phase 8: Follow-up — CT1 logging redaction (Constitution Principle V), Record the requirement, Tests for CT1 (write first; they must fail)

### Community 128 - "LibraryChange"
Cohesion: 0.25
Nodes (6): LibraryChange, deleted, reloaded, saved, LibraryChangeRegistry, .changes

### Community 129 - "SimulationPanel"
Cohesion: 0.12
Nodes (8): MainScreenModel, StockDraft, SimulationPanel, .body, .controls, .findingsList, .navigation, .preview

### Community 130 - "Contract: Machine Profile"
Cohesion: 0.17
Nodes (6): Conformance rules used by validation, Contract: Machine Profile, Controller setup is not program content, Invariants, Profile document schema, Values fixed by the constitution

### Community 131 - "PreviewMeshTests.swift"
Cohesion: 0.60
Nodes (5): aFlatHeightmapHasUpwardNormalsAndOneSurfaceLevel(), flatHeightmap(), previewMeshHasValidPositionsNormalsAndIndices(), previewMeshIsDeterministicForAKnownHeightmap(), slopedHeightmap()

### Community 135 - "FakeError"
Cohesion: 0.67
Nodes (3): FakeError, missing, write

### Community 136 - "quickstart.md"
Cohesion: 0.12
Nodes (11): Bundle verification — 001-stl-to-gcode, Entitlements, Launch, Re-verification (2026-11-20), Signature and identifier, Still owed (desktop-only) — T115, Automated static audit (FR-074), Full-session observation (VS-8 / SC-010) — pending human verification (+3 more)

### Community 137 - ".job"
Cohesion: 0.07
Nodes (35): MaterialValidationError, duplicateIdentifier, duplicateName, emptyName, invertedBand, nonPositiveBound, bandsOutsideMachineLimitsAreStillValidRecords(), duplicateNamesAndPresetShadowingAreRejected() (+27 more)

### Community 139 - "Tasks: STL to Machine-Ready G-code"
Cohesion: 0.12
Nodes (16): Format: `[ID] [P?] [Story] Description`, Implementation for User Story 2, Implementation Strategy, Incremental Delivery, MVP First (User Story 1 Only), Notes, Parallel Team Strategy, Path Conventions (+8 more)

### Community 140 - "CameraNavigation"
Cohesion: 0.15
Nodes (9): CameraNavigation, orbitDown, orbitLeft, orbitRight, orbitUp, reset, zoomIn, zoomOut (+1 more)

### Community 143 - "DiagnosticCategory"
Cohesion: 0.18
Nodes (10): DiagnosticCategory, cutters, decode, materials, pipeline, plan, render, simulate (+2 more)

### Community 144 - "MainScreenGenerationStatus"
Cohesion: 0.09
Nodes (14): AccessibilityAdaptations, KeyboardHelpView, .body, .body, CutterLibraryCommands, .body, MainScreenCommands, MainScreenGenerationStatus (+6 more)

### Community 145 - ".render"
Cohesion: 0.31
Nodes (3): HeaderBuilder, NumericFormatting, ProfileBlockRenderer

### Community 147 - "RenderingError"
Cohesion: 0.25
Nodes (6): LineGuard, RenderingError, emptyToolpath, lineTooLong, missingTemplateValue, nonASCIILine

### Community 148 - "FeatureReport"
Cohesion: 0.27
Nodes (3): FeatureReport, .isAchievable, Preflight

### Community 149 - "ContractFileSystem"
Cohesion: 0.24
Nodes (7): ContractFileSystem, cutter(), deletingAnotherCutterLeavesTheSelectionIntact(), deletingTheSelectedCutterClearsSelectionAndBlocksGeneration(), readyModel(), savedCutterEventReResolvesTheSelectedIdentifier(), storedCutters()

### Community 150 - "Foundation"
Cohesion: 0.15
Nodes (12): AppKit, CNCCutters, CNCCuttersStore, CNCStorage, CutterLibraryModalUI, MainScreenUI, manifest(), modalPackageDoesNotDependOnTheMainScreen() (+4 more)

### Community 151 - "Specification Quality Checklist: STL to Machine-Ready G-code"
Cohesion: 0.29
Nodes (5): Content Quality, Feature Readiness, Notes, Requirement Completeness, Specification Quality Checklist: STL to Machine-Ready G-code

### Community 153 - "FileSystem"
Cohesion: 0.05
Nodes (23): FileWriter, OutputFileName, derivesDeterministicASCIIFileNameFromModelBasename(), emptyDerivedNameFallsBackToCarveNc(), FakeFileSystem, noFileIsWrittenOnCancellation(), noPartialFileRemainsOnFailure(), replacesExistingFileAtomically() (+15 more)

### Community 154 - "GenerationBlocker"
Cohesion: 0.07
Nodes (23): Geometry, CutterGeometry, ballNose, flat, vBit, CutterGeometrySupport, PointKey, SegmentKey (+15 more)

### Community 155 - "String"
Cohesion: 0.05
Nodes (28): CutterType, ballNose, flat, vBit, AccessibilityPriority, AccessibilityText, ContrastAwareError, CutterEditor (+20 more)

### Community 157 - "Sendable"
Cohesion: 0.11
Nodes (22): GCodeRendering, ProgramWriter, GenerationRequest, PipelineOutcome, blocked, cancelled, ready, PipelineRunning (+14 more)

### Community 161 - "ResolutionOutcome"
Cohesion: 0.31
Nodes (5): MaterialResolver, MaterialResolving, ResolutionOutcome, noOverlap, resolved

### Community 169 - "PipelineError"
Cohesion: 0.29
Nodes (7): PipelineError, blockedProgram, cancelledProgram, incompleteConfirmation, notReady, unacknowledgedViolations, .userMessage

### Community 170 - "SensitiveValue"
Cohesion: 0.19
Nodes (8): SensitiveValue, .logDescription, emitterDoesNotLogTheWholeMessageWithPublicPrivacy(), packageRoot(), sensitiveValueNeverAppearsInClearText(), shippingSourcesDoNotConstructLoggersDirectly(), typedFailureWithSensitivePayloadKeepsStableMetadata(), Post-Design Constitution Re-check

### Community 171 - "PULL_REQUEST_TEMPLATE.md"
Cohesion: 0.33
Nodes (5): Evidence, Human verification still owed, Principles touched, Summary, Verification

### Community 172 - "Accessibility support record — 001-stl-to-gcode"
Cohesion: 0.29
Nodes (6): Accessibility support record — 001-stl-to-gcode, Implemented (T104, T105), Labels, roles, values, and reading order (FR-070), Remaining human verification (SC-009, T113/T114), System settings (FR-071), Verification completed

### Community 174 - "JobSuggestion"
Cohesion: 0.16
Nodes (5): ConfirmUnitsSheet, .body, .parsedScale, JobSuggestion, UnitsConfirmationDraft

### Community 180 - "DialectPurityTests.swift"
Cohesion: 0.44
Nodes (7): emissionStagesDoNotHardcodeMachineLimitConstants(), emissionStagesDoNotHardcodeUnsupportedDialectTokens(), emitterReadsBlocksAndLimitsFromTheProfile(), generationSource(), profileIsTheSingleSourceOfDialectAndLimits(), repositoryRoot(), swiftFiles()

### Community 184 - "Dependencies & Execution Order"
Cohesion: 0.40
Nodes (5): Dependencies & Execution Order, Parallel opportunities, Phase dependencies, User story dependencies, Within each user story

### Community 189 - "WriteBoundaryTests.swift"
Cohesion: 0.48
Nodes (4): onlyThePipelinePackageDependsOnTheWriter(), onlyWriterPackagesReferenceTheProgramWriter(), repositoryRoot(), swiftFiles()

### Community 190 - "HardwareBoundaryTests.swift"
Cohesion: 0.48
Nodes (4): noHardwareDriverDependencyInAnyManifest(), noHardwareSurfaceInAnyPackageSource(), repositoryRoot(), swiftFiles()

## Knowledge Gaps
- **202 isolated node(s):** `os`, `.description`, `.userMessage`, `decode`, `plan` (+197 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1020 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **56 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Implementation Plan: STL to Machine-Ready G-code` connect `Implementation Plan: STL to Machine-Ready G-code` to `SensitiveValue`, `Contract: Machine Profile`?**
  _High betweenness centrality (0.074) - this node is a cross-community bridge._
- **Are the 42 inferred relationships involving `Vec3` (e.g. with `EmitterFixture` and `.job()`) actually correct?**
  _`Vec3` has 42 INFERRED edges - model-reasoned connections that need verification._
- **What connects `os`, `.description`, `.userMessage` to the rest of the system?**
  _202 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Skill: Test Script (Grafana k6)` be split into smaller, more focused modules?**
  _Cohesion score 0.06628787878787878 - nodes in this community are weakly interconnected._
- **Why does `Foundation` connect `CNCMachineProfile` to `EffectiveCuttingValues`, `.job`, `Testing`, `Foundation`, `FileSystem`, `GenerationBlocker`, `String`, `SensitiveValue`, `STLDecoderTests.swift`, `DialectPurityTests.swift`, `MaterialBand`, `FakeFileSystem`, `MeshDocument`, `WriteBoundaryTests.swift`, `CommitTests.swift`, `HardwareBoundaryTests.swift`, `CorrelationID`, `isRapid`, `.date`, `LoadOutcomeTests.swift`, `CutterValidationError`, `Finding`, `Material`, `BoundaryTests.swift`, `Codable`, `MachineProfile`, `.job`, `MaterialStoreTests.swift`, `.save`, `CutterLibraryStore`, `Vec3`?**
  _High betweenness centrality (0.053) - this node is a cross-community bridge._
- **Should `steps` be split into smaller, more focused modules?**
  _Cohesion score 0.06451612903225806 - nodes in this community are weakly interconnected._
- **Why does `EffectiveCuttingValues` connect `EffectiveCuttingValues` to `ResolutionOutcome`, `SimulationPanel`, `.job`, `.date`, `MaterialPanel`, `JobSuggestion`, `Implementation Plan: STL to Machine-Ready G-code`, `MachineProfile`, `Equatable`, `AppComposition`, `.job`, `Material`, `MainScreenModelTests.swift`, `MeshDocument`, `Sendable`?**
  _High betweenness centrality (0.040) - this node is a cross-community bridge._