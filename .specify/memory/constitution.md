<!--
Sync Impact Report
==================
Version change: 2.4.1 -> 2.5.0 (MINOR: spindle-only scope added)

Modified principles:
- I. Swift 6 Language Mode and Strict Concurrency - unchanged
- II. Modular Package-First Architecture - unchanged
- III. Test-First - unchanged
- IV. Native macOS Fidelity and Accessibility - unchanged
- V. Observability, Diagnostics, and Error Discipline - unchanged
- VI. Image and STL to Machine-Ready G-code - expanded: spindle-only tool activation, RPM
  spindle speed, laser output prohibited
- VII. Two Modes over One Cutter Library - unchanged

Added sections: none
Removed sections: none

Narrowed TODOs:
- TODO(MACHINE_PROFILE): tool activation is now decided (spindle only), so the remaining
  unknowns are dialect/firmware, envelope, feed and rapid limits, spindle speed range, and
  start/stop sequences.

Follow-up TODOs:
- TODO(SIGNING_IDENTITY): bundle identifier, signing team, notarization unknown.
- TODO(MACHINE_PROFILE): dialect/firmware, work envelope, feed and rapid limits, spindle
  speed range, and start/stop sequences are undecided.
- TODO(TOOL_ADMIN_SCOPE): whether cutter administration also covers wear and life tracking,
  tool-change sheets, or machine offsets is unstated.
-->

# CNCswift Constitution

## Core Principles

### I. Swift 6 Language Mode and Strict Concurrency (NON-NEGOTIABLE)

All production code MUST compile in Swift 6 language mode with complete concurrency
checking and zero concurrency warnings (`SWIFT_STRICT_CONCURRENCY = complete`, diagnosed
as errors before merge).

- Mutable shared state MUST be isolated to an actor, `@MainActor`, or an immutable value;
  `@unchecked Sendable` requires written justification in the pull request.
- UI state MUST be `@MainActor`. Blocking work MUST NOT run on the main actor, and
  long-running work MUST be cancellable through structured `Task` cancellation.
- `Task.detached`, global `DispatchQueue` state, and fire-and-forget closures over mutable
  state MUST NOT replace structured concurrency.
- Force unwrap, `try!`, `as!`, and `fatalError` in shipping paths MUST be justified in
  review; a guarded failure or thrown error is the default.

Rationale: data races in a control application are safety defects, not style issues.

### II. Modular Package-First Architecture

The app MUST be a thin macOS shell over local Swift packages.

- Domain logic, persistence, and hardware/IO adapters MUST live in their own packages under
  `Packages/`, buildable and testable with `swift build` and `swift test`.
- The app target MUST contain only the composition root, scene/view wiring, and platform
  presentation. Business rules MUST NOT live in views.
- Dependencies MUST flow one way: presentation -> domain -> adapters. Cycles, imports of
  another feature's internals, and `@_exported` re-exports are prohibited unless a
  documented umbrella module exists.
- `public` MUST be a deliberate decision; everything else stays `internal`.
- Third-party dependencies MUST be pinned or range-constrained in `Package.swift` and
  justified in the feature plan.

Rationale: independently testable modules keep the domain verifiable without a GUI.

### III. Test-First (NON-NEGOTIABLE)

Tests MUST precede implementation and MUST fail for the right reason first.

- New behavior REQUIRES a failing test, then Red -> Green -> Refactor. A pull request that
  adds behavior without a test is incomplete.
- New tests MUST use Swift Testing (`import Testing`); XCTest is limited to UI automation
  and APIs Swift Testing cannot cover.
- Every module MUST have a test target, and its `swift test` MUST pass before work is
  called done.
- Tests MUST be deterministic: no sleeps, real network, real time, or machine-local state.
  Hardware, filesystem, and clock access MUST go through injectable protocols or fakes.
- Bug fixes MUST include a regression test that fails on the pre-fix code.

Rationale: untested control logic is unverified logic.

### IV. Native macOS Fidelity and Accessibility

The app MUST behave like a first-class macOS application, not a ported mobile UI.

- SwiftUI is the default UI framework; AppKit MAY be used only where SwiftUI cannot meet
  the requirement, with the reason recorded in the technical design.
- Every primary workflow MUST be operable by keyboard alone. Custom controls MUST expose
  accessibility labels, roles, and values, and the app MUST honor VoiceOver, Increase
  Contrast, Reduce Motion, and full keyboard access.
- Windows, menus, toolbars, commands, and settings MUST follow Human Interface Guidelines
  conventions, including a menu bar, standard shortcuts, and window restoration.
- The app MUST be sandboxed with only the entitlements it uses; file, network, and hardware
  access MUST be declared and explained in the feature plan.
- User data MUST NOT leave the machine without per-feature consent recorded in the
  specification.

Rationale: platform convention and accessibility are how macOS users judge quality.

### V. Observability, Diagnostics, and Error Discipline

Failures MUST be diagnosable from logs alone.

- Logging MUST use `os.Logger` with a per-module subsystem and stable categories; `print`,
  `NSLog`, and `debugPrint` MUST NOT appear in shipping code.
- Errors MUST be typed and propagated. The user sees an actionable message; the log
  records the cause and a correlation identifier.
- Long-running operations MUST report progress and be cancellable, and cancellation MUST be
  distinguished from failure in both logs and UI.
- No secret, credential, or identifying value MAY be logged; sensitive payloads MUST be
  redacted or marked private.
- Public API MUST carry DocC comments covering preconditions, thrown errors, and
  concurrency expectations.

Rationale: structured logs and typed errors turn a support report into a reproducible bug.

### VI. Image and STL to Machine-Ready G-code

The G-code creation mode has exactly two input families, images and STL meshes, and one
output: a G-code file that the target machine accepts.

- Stages MUST be separate packages with typed boundaries: decode, toolpath generation,
  post-processing, and validation. No stage imports UI, and no view parses files or formats
  G-code.
- Inputs MUST be validated, and invalid ones rejected with actionable errors: unsupported or
  corrupt files, empty or non-manifold meshes, zero-area images. Silent repair and silent
  default scaling are prohibited; missing scale, units, or orientation MUST be requested
  explicitly.
- Geometry MUST be millimetres in a declared coordinate system and origin. The transform
  from image or mesh space to machine space MUST be explicit and covered by tests.
- The target machine (TwoTrees TTC450 PRO) MUST be described by one versioned machine
  profile holding its dialect, work envelope, feed and rapid limits, tool activation, and
  supported G/M codes. Pipeline code MUST NOT hardcode dialect tokens; another machine is a
  new profile, never a new code path.
- Only spindle tool activation is supported. G-code MUST select the spindle with the machine
  profile's spindle command and express speed in RPM. Laser-specific output, including power
  modulation, laser-mode enable settings, and dynamic-power moves, MUST NOT be emitted.
  Adding laser support requires an amendment.
- Emitted G-code MUST be validated before it is written: it MUST parse, stay inside the
  envelope and declared limits, and include the profile's start, stop, and mode-setting
  block. Geometry the profile cannot represent MUST fail loudly, never be approximated
  silently.
- Generation MUST be deterministic: the same input, settings, and profile MUST produce
  byte-identical output apart from a documented header.
- The app writes files. It MUST NOT stream to, drive, or control machine hardware; adding
  that capability requires an amendment.

Rationale: the G-code is the product. A toolpath the controller rejects, or one that cuts
outside the bed, is a broken build, not a cosmetic bug.

### VII. Two Modes over One Cutter Library

The application has exactly two user-facing modes: mill cutter administration and G-code
creation. They MUST stay separable, and they MUST share exactly one cutter definition.

- Each mode MUST be a separate module with its own view models and its own entry point, and
  each MUST be usable without the other running. Modes MUST NOT share mutable in-memory
  state; the persisted cutter library is the only shared contract between them.
- Cross-mode imports are limited to the cutter library, shared geometry, and shared
  persistence packages. A mode MUST NOT reach into another mode's views or internal types.
- The cutter library MUST be the single authoritative record of mill cutters (end mills) and
  their typed attributes. G-code creation MUST consume cutters read-only and MUST NOT define,
  override, or silently default cutter parameters; a missing required attribute blocks
  generation with an actionable error.
- Cutter records MUST have stable identifiers, MUST be validated on entry (positive
  dimensions, valid flute count, feeds and speeds inside the machine profile's limits), and
  MUST be rejected at entry rather than at generation time.
- Generated output MUST record the cutter identifier and the attribute values actually used,
  in the documented file header, so a file can be reproduced after the library changes.
  Saved work MUST reference cutters by identifier, never by copied values.
- Library storage MUST live in Application Support, be written atomically, carry a versioned
  schema, and migrate forward with tested fixtures. Destructive or lossy migration is
  prohibited.
- Cutter type MUST be a closed enumeration of flat, ball nose, and V-bit. A cutter MUST NOT
  be stored as an untyped diameter.
- Every cutter MUST record its shank diameter, cutting length, and flute count, plus the
  dimensions that define its type: cutting diameter for flat, ball diameter for ball nose,
  and included angle plus tip diameter for V-bit. A type MUST reject another type's fields as
  a substitute, and a bare `diameter` field MUST NOT be shared across types where its meaning
  differs.
- Dimensions MUST be millimetres with one defined meaning per type. Validation MUST reject
  impossible geometry at entry: non-positive sizes, an included angle that cannot form a
  cone, or a tip wider than the shank.
- Cutter type and the dimensions actually used MUST appear in the generated file header.
  Toolpaths whose shape depends on cutter geometry MUST be recomputed when that geometry
  changes and MUST NOT be reused from a cache.

Rationale: duplicated cutter data is how a router ends up cutting with the wrong end mill.
Two isolated modes over one library keep the toolpath reproducible from a file already cut.

## Technology Stack and Toolchain

- Language: Swift 6 language mode; mixing another language requires an amendment.
- Platform: macOS only, exclusively. Minimum deployment target: macOS 27.0. Targets for iOS,
  iPadOS, tvOS, watchOS, visionOS, Mac Catalyst, Linux, or Windows MUST NOT be added,
  cross-platform UI toolkits MUST NOT be introduced, and no other-platform requirement MAY
  shape the design. Raising the deployment target requires an amendment.
- Build: Swift Package Manager for every module. The Xcode project MUST consume the
  packages and MUST NOT duplicate their sources.
- Toolchain: current stable Xcode, pinned in CI and documented in `AGENTS.md` once CI exists.
- Formatting: `swift-format` configured at the repository root, applied to all Swift
  sources, enforced in CI. First-party targets MUST treat warnings as errors.
- Dependencies: Apple frameworks first. Every third-party package MUST be justified,
  maintained, and license-compatible with distribution outside the App Store unless stated.
- Inputs: raster image formats and STL (ASCII and binary) MUST be decoded by first-party
  packages or declared Apple frameworks, and a format is supported only once covered by
  fixtures.
- Output: G-code files for the machine profile under Principle VI. No other machine-control
  artifact is in scope without an amendment.
- Machine profile: dialect, envelope, feed and rapid limits, spindle speed range, and
  start/stop sequences are TODO(MACHINE_PROFILE) and MUST be fixed before the first generator
  release. Tool activation is spindle-only; laser output is out of scope.
- Distribution, bundle identifier, signing, and notarization are TODO(SIGNING_IDENTITY) and
  MUST be settled before a release plan is written.

## Development Workflow and Quality Gates

- Work follows `spec.md` -> `plan.md` -> `tasks.md` -> implementation. Implementation MUST
  NOT begin before `plan.md` and `tasks.md` exist.
- Every `plan.md` MUST include a Constitution Check mapping each principle to a verification
  step; a failing or skipped check blocks the plan.
- A task is complete only when its tests pass, the module builds without warnings, and
  `swift-format` lint is clean.
- Generator changes MUST add or update golden-file fixtures (input -> reviewed output) and
  pass envelope and limit-conformance tests; a changed expected file MUST be reviewed as
  production output.
- Changes spanning both modes MUST include a tool-library contract test proving that a
  cutter edited in one mode produces the expected output in the other, and schema migrations
  MUST be tested against fixtures from the prior version.
- Pull requests MUST be small, state the principles they touch, and MUST NOT merge with
  failing or disabled tests or skipped concurrency checks.
- `AGENTS.md` MUST record the build, test, and lint commands once they exist; it is the
  source for day-to-day invocation.
- Ambiguity MUST be resolved in `spec.md` or `clarify`, not in code.

## Governance

- This constitution supersedes conflicting conventions and prior practice; a principle wins
  until it is amended.
- Amendments require a written proposal with migration impact, review approval, and an
  update to this file with a Sync Impact Report.
- Versioning: MAJOR for incompatible principle removals or redefinitions, MINOR for new
  principles or materially expanded guidance, PATCH for clarifications.
- Every review MUST verify compliance; non-compliance MUST be recorded as a finding, never
  waived silently.
- Complexity MUST be justified against Principle II: new modules, dependencies, and
  `@unchecked Sendable` all require explicit rationale.
- `AGENTS.md` holds runtime guidance; this file governs intent, not command syntax.
- TODO(SIGNING_IDENTITY), TODO(MACHINE_PROFILE), and TODO(TOOL_ADMIN_SCOPE) MUST be resolved
  by amendment.

**Version**: 2.5.0 | **Ratified**: 2026-11-12 | **Last Amended**: 2026-11-13
