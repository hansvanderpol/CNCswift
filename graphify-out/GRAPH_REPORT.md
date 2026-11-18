# Graph Report - CNCswift  (2026-11-18)

## Corpus Check
- 121 files · ~76,046 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 12 file(s) not represented in the graph (top: .stl 5, (none) 3, .ini 2)

## Summary
- 765 nodes · 755 edges · 76 communities (53 shown, 23 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 11 edges (avg confidence: 0.77)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `08fe7cb3`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Contract: Cutter Library
- Skill: Test Script (Grafana k6)
- steps
- common.sh
- Tasks: [FEATURE NAME]
- Tasks: STL to Machine-Ready G-code
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
- Contract: G-code Output File
- Contract: Machine Profile
- Specification Quality Checklist: STL to Machine-Ready G-code
- PackageDescription
- Quickstart: STL to Machine-Ready G-code
- Reference Fixtures
- ci.sh
- make-app.sh

## God Nodes (most connected - your core abstractions)
1. `Phase 1 Data Model: STL to Machine-Ready G-code` - 18 edges
2. `PackageDescription` - 17 edges
3. `Phase 0 Research: STL to Machine-Ready G-code` - 17 edges
4. `Testing` - 16 edges
5. `Tasks: STL to Machine-Ready G-code` - 14 edges
6. `Contract: Stage Boundaries` - 14 edges
7. `Tasks: [FEATURE NAME]` - 13 edges
8. `Contract: Cutter Library` - 11 edges
9. `End-to-end validation scenarios` - 11 edges
10. `create-new-feature.sh script` - 11 edges

## Surprising Connections (you probably didn't know these)
- `Repository state` --references--> `CNCswiftApp`  [INFERRED]
  AGENTS.md → App/Sources/CNCswiftApp/CNCswiftApp.swift
- `Phase 1: Setup (Shared Infrastructure)` --references--> `CNCswiftApp`  [INFERRED]
  specs/001-stl-to-gcode/tasks.md → App/Sources/CNCswiftApp/CNCswiftApp.swift
- `2. Extract the schema (what to read from where)` --references--> `headers()`  [INFERRED]
  .opencode/skills/test-script-k6/references/openapi-grounding.md → .opencode/skills/test-script-k6/references/config-skeleton.js
- `Ground the schema (OpenAPI 3.x)` --references--> `headers()`  [INFERRED]
  .opencode/skills/test-script-k6/SKILL.md → .opencode/skills/test-script-k6/references/config-skeleton.js
- `Output` --references--> `headers()`  [INFERRED]
  .opencode/skills/test-script-k6/SKILL.md → .opencode/skills/test-script-k6/references/config-skeleton.js

## Import Cycles
- None detected.

## Communities (76 total, 23 thin omitted)

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

### Community 5 - "Tasks: STL to Machine-Ready G-code"
Cohesion: 0.07
Nodes (28): Dependencies & Execution Order, Format: `[ID] [P?] [Story] Description`, Implementation for Foundation, Implementation for User Story 1, Implementation for User Story 2, Implementation for User Story 3, Implementation Strategy, Incremental Delivery (+20 more)

### Community 6 - "speckit.analyze.md"
Cohesion: 0.08
Nodes (25): 1. Initialize Analysis Context, 2. Load Artifacts (Progressive Disclosure), 3. Build Semantic Models, 4. Detection Passes (Token-Efficient Analysis), 5. Severity Assignment, 6. Produce Compact Analysis Report, 7. Provide Next Actions, 8. Offer Remediation (+17 more)

### Community 7 - "Technical Design - [Feature Title]"
Cohesion: 0.08
Nodes (24): API Design, `/api/v1/foo/bar`, Basic Flow, Basic Logic, Changelog, Database Design, Entry Point 1 (e.g. API /api/v1/foo/bar), Failure & Retry Registry (+16 more)

### Community 8 - "Functional Requirements"
Cohesion: 0.08
Nodes (24): Assumptions, Carving material, Clarifications, Cutter library, Diagnostics, accessibility, and privacy, Edge Cases, Feature Specification: STL to Machine-Ready G-code, Functional Requirements (+16 more)

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
Nodes (15): Complexity Tracking, Constitution Check, Design Flow, Documentation (this feature), Implementation Plan: STL to Machine-Ready G-code, Package dependency graph, Package rationale (Principle II), Post-Design Constitution Re-check (+7 more)

### Community 14 - "AGENTS.md"
Cohesion: 0.10
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

### Community 52 - "Contract: G-code Output File"
Cohesion: 0.22
Nodes (9): Body formatting, Contract: G-code Output File, Example fragment, Explicitly forbidden in output, File-level rules, Header, Output filename, Program body order (+1 more)

### Community 53 - "Contract: Machine Profile"
Cohesion: 0.29
Nodes (6): Conformance rules used by validation, Contract: Machine Profile, Controller setup is not program content, Invariants, Profile document schema, Values fixed by the constitution

### Community 54 - "Specification Quality Checklist: STL to Machine-Ready G-code"
Cohesion: 0.40
Nodes (5): Content Quality, Feature Readiness, Notes, Requirement Completeness, Specification Quality Checklist: STL to Machine-Ready G-code

### Community 56 - "Quickstart: STL to Machine-Ready G-code"
Cohesion: 0.29
Nodes (7): Format check, Manual controller check, Prerequisites, Quickstart: STL to Machine-Ready G-code, Run, Setup, Test commands

### Community 57 - "Reference Fixtures"
Cohesion: 0.40
Nodes (4): Amendment rule, Other fixture directories, Reference Fixtures, Reference STL models (exactly five)

## Knowledge Gaps
- **1 isolated node(s):** `.body`
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 574 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **23 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Feature Specification: STL to Machine-Ready G-code` connect `Functional Requirements` to `plan.md`?**
  _High betweenness centrality (0.011) - this node is a cross-community bridge._
- **What connects `.body` to the rest of the system?**
  _1 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Skill: Test Script (Grafana k6)` be split into smaller, more focused modules?**
  _Cohesion score 0.06628787878787878 - nodes in this community are weakly interconnected._
- **Why does `Phase 1 Data Model: STL to Machine-Ready G-code` connect `Phase 1 Data Model: STL to Machine-Ready G-code` to `plan.md`?**
  _High betweenness centrality (0.009) - this node is a cross-community bridge._
- **Should `steps` be split into smaller, more focused modules?**
  _Cohesion score 0.06451612903225806 - nodes in this community are weakly interconnected._
- **Why does `Quickstart: STL to Machine-Ready G-code` connect `Quickstart: STL to Machine-Ready G-code` to `End-to-end validation scenarios`, `plan.md`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **Should `common.sh` be split into smaller, more focused modules?**
  _Cohesion score 0.11470985155195682 - nodes in this community are weakly interconnected._