<!--
Sync Impact Report
==================
Version change: 2.5.0 -> 2.19.0 (fourteen MINOR amendments plus two PATCHes, all still
uncommitted)

Amendments:
- 2.6.0 MINOR: output dialect fixed to standard G-code (ISO 6983 / RS-274); output file
  extension fixed to .nc.
- 2.7.0 MINOR: spindle narrowed to on/off only. Withdrawn before commit.
- 2.8.0 MINOR: spindle speed control restored to the published TTC450 PRO specification:
  variable 8,000-30,000 RPM, set with an S word and validated against the profile range.
- 2.9.0 MINOR: dialect narrowed from ISO 6983 / RS-274 to GRBL 1.1, the dialect the TTC450
  PRO controller runs; commands GRBL does not implement MUST NOT be emitted.
- 2.9.1 PATCH: spindle range confirmed as the 8,000-30,000 RPM spindle supplied with the
  TTC450 PRO; the per-installed-module hedge is removed.
- 2.10.0 MINOR: maximum feed rate fixed at 800 mm/min; feeds above the maximum MUST be
  rejected, never clamped.
- 2.11.0 MINOR: spindle top speed corrected to 8,000 RPM for the supplied spindle; the
  published 8,000-30,000 RPM range does not apply to this machine. Minimum commandable speed
  is deferred to the machine profile.
- 2.12.0 MINOR: work envelope fixed at 460 x 460 x 80 mm; the envelope is removed from the
  remaining profile TODOs.
- 2.13.0 MINOR: minimum spindle speed fixed at 5,000 RPM; the supported range is
  5,000-8,000 RPM. Speeds below 5,000 RPM give poor cutting results and MUST be rejected.
- 2.14.0 MINOR: maximum rapid-travel rate fixed at 800 mm/min, matching the feed ceiling;
  rapids above the limit MUST be rejected, never clamped or downgraded to a cutting feed.
- 2.15.0 MINOR: mandatory start block fixed: G21, G90, G94, G00 Z10.0, M3 S8000, in that
  order, before any cutting move. The start sequence is removed from the profile TODOs; the
  stop block remains TODO(MACHINE_PROFILE).
- 2.15.1 PATCH: the 5,000-8,000 RPM spindle range is stated as inclusive of both endpoints.
  No new limit; the v2.13.0 range is confirmed unchanged.
- 2.16.0 MINOR: controller firmware and firmware version are removed from the machine
  profile. The profile is defined by the GRBL 1.1 dialect and the machine's mechanical and
  spindle limits; the app MUST NOT detect, query, or depend on a firmware version. The
  firmware/version TODO is withdrawn.
- 2.17.0 MINOR: mandatory stop block fixed: G90, G00 Z15.0, M5, G00 X0 Y0, M30, in that
  order, after the last cutting move. The stop block is removed from the profile TODOs.
- 2.18.0 MINOR: controller spindle limits recorded. `$30` is the maximum spindle speed and
  `$31` the minimum; the profile requires `$30 = 8000` and `$31 = 5000`, set as machine
  setup. The app MUST NOT read or change controller settings. TODO(MACHINE_PROFILE) is
  resolved and withdrawn.
- 2.19.0 MINOR: bundle identifier fixed at `com.hansvanderpol.CNCswift` and locked against
  change without an amendment. Signing team and notarization stay TODO(SIGNING_IDENTITY).

Modified principles:
- I. Swift 6 Language Mode and Strict Concurrency - unchanged
- II. Modular Package-First Architecture - unchanged
- III. Test-First - unchanged
- IV. Native macOS Fidelity and Accessibility - unchanged
- V. Observability, Diagnostics, and Error Discipline - unchanged
- VI. Image and STL to Machine-Ready G-code - unchanged; fixed start and stop blocks,
  800 mm/min rapid-travel ceiling, 5,000-8,000 RPM spindle range, 460 x 460 x 80 mm envelope,
  800 mm/min feed ceiling, GRBL 1.1 dialect, and .nc output retained
- VII. Two Modes over One Cutter Library - unchanged

Added sections: none
Removed sections: none

Open TODOs: none. The machine profile has no unresolved facts.

Follow-up TODOs:
- TODO(SIGNING_IDENTITY): signing team and notarization unknown; the bundle identifier is
  fixed at `com.hansvanderpol.CNCswift`.
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
  supported G/M codes. The work envelope is 460 x 460 x 80 mm (X x Y x Z). Tool activation
  is spindle-only, with speed set by an S word inside the profile's range. Pipeline code MUST
  NOT hardcode dialect tokens; another machine is a new profile, never a new code path.
- The profile's dialect MUST be GRBL 1.1, the dialect the TTC450 PRO controller runs.
  Emitted programs MUST use only commands GRBL 1.1 implements; ISO 6983 / RS-274 features
  GRBL does not implement, including `G43` tool-length offsets and `M6` tool changes, MUST
  NOT be emitted. Vendor macros, custom M-codes, and controller extensions MUST NOT be
  required to run a generated file. A controller with a different dialect is a new profile,
  never a new code path.
- Generated G-code MUST be written as a single plain-text file whose name uses the `.nc`
  extension. Alternate extensions (`.gcode`, `.tap`, `.ngc`) MUST NOT be produced for this
  profile without an amendment.
- Only spindle tool activation is supported. G-code MUST start and stop the spindle with the
  machine profile's spindle commands and MUST carry the spindle speed as an `S` word in RPM.
  The supplied spindle runs between 5,000 and 8,000 RPM inclusive, so a commanded speed
  outside that range MUST be rejected, never clamped; speeds below 5,000 RPM give poor
  cutting results and MUST NOT be emitted. Laser-specific output, including power modulation,
  laser-mode enable settings, and dynamic-power moves, MUST NOT be emitted. Adding laser
  support requires an amendment.
- Every generated program MUST open with the profile's start block, in exactly this order and
  with no line omitted, before any cutting move:

  ```gcode
  G21         ; Set units to millimeters
  G90         ; Use absolute positioning
  G94         ; Feed rate per minute mode
  G00 Z10.0   ; Raise Z-axis to a safe clearance height
  M3 S8000    ; Start spindle clockwise at 8,000 RPM
  ```

  The sequence MUST NOT be reordered, truncated, or made conditional. The `S` word in the
  `M3` line carries the program's spindle speed: the supplied sequence uses 8,000 RPM, and a
  program that selects a different speed MUST emit that speed in place of `S8000`, still
  inside the 5,000-8,000 RPM range.
- Every generated program MUST end with the profile's stop block, in exactly this order and
  with no line omitted, after the last cutting move:

  ```gcode
  G90         ; Ensure absolute positioning is active
  G00 Z15.0   ; Lift the bit 15 mm above the work surface
  M5          ; Turn off the 80W spindle
  G00 X0 Y0   ; Return the spindle to the work origin
  M30         ; End the program and reset the GRBL controller
  ```

  The sequence MUST NOT be reordered or truncated. `M5` MUST stop the spindle before the
  program returns to the origin, and `M30` MUST be the final line of every file, so a program
  never ends with the spindle running or with the bit at cutting depth.
- Emitted feed rates MUST NOT exceed the machine profile's maximum feed rate, which is
  800 mm/min for the TTC450 PRO. A feed rate above the maximum MUST be rejected, never
  clamped.
- Emitted rapid moves MUST NOT exceed the machine profile's maximum rapid-travel rate, which
  is also 800 mm/min for the TTC450 PRO. A rapid above that limit MUST be rejected, never
  clamped or silently downgraded to a cutting feed.
- Emitted G-code MUST be validated before it is written: it MUST parse as GRBL 1.1, stay
  inside the profile's 460 x 460 x 80 mm envelope and declared limits, and carry the fixed
  start and stop blocks verbatim in their declared order. Geometry the profile cannot
  represent MUST fail loudly, never be approximated silently.
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
  dimensions, valid flute count, feed rates and spindle speeds inside the machine profile's
  limits), and MUST be rejected at entry rather than at generation time.
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
- Output: G-code files with the `.nc` extension, in the machine profile's dialect under
  Principle VI. No other machine-control artifact is in scope without an amendment.
- Machine profile: the dialect is GRBL 1.1. The work envelope is 460 x 460 x 80 mm
  (X x Y x Z). The supplied spindle runs 5,000-8,000 RPM inclusive. The controller supports
  `$30` as the maximum spindle speed and `$31` as the minimum, so the profile requires
  `$30 = 8000` and `$31 = 5000`; setting them is machine setup, not app behaviour, and the
  app MUST NOT read or change controller settings. The maximum feed rate is 800 mm/min and
  the maximum rapid-travel rate is also 800 mm/min, so every emitted move is capped at that
  rate. Every program opens with the fixed start block under Principle VI: `G21`, `G90`,
  `G94`, `G00 Z10.0`, and `M3` with an `S` word. Every program closes with the fixed stop
  block under Principle VI: `G90`, `G00 Z15.0`, `M5`, `G00 X0 Y0`, and `M30`. Controller
  firmware and firmware version are explicitly out of scope for the implementation: the
  profile is defined by the GRBL 1.1 dialect and the machine's mechanical and spindle
  limits, not by a firmware build, and the app MUST NOT detect, query, or depend on a
  firmware version. Tool activation is spindle-only; laser output is out of scope.
- Distribution: the app is built and run locally on the developer's Mac. It is not prepared
  for the App Store or any other distribution channel: no App Store submission, no Developer
  ID signing, and no notarization. Local development builds use Xcode's default local signing
  only, and producing a distributable signed or notarized artifact requires an amendment. The
  bundle identifier is `com.hansvanderpol.CNCswift` and MUST NOT change without an
  amendment.

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
- TODO(SIGNING_IDENTITY) and TODO(TOOL_ADMIN_SCOPE) MUST be resolved by amendment.

**Version**: 2.19.0 | **Ratified**: 2026-11-12 | **Last Amended**: 2026-11-13
