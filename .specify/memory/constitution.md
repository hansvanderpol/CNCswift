<!--
Sync Impact Report
==================
Version change: 2.0.0 -> 2.1.0 (MINOR: platform scope materially expanded)

Modified principles:
- I. Swift 6 Language Mode and Strict Concurrency - unchanged
- II. Modular Package-First Architecture - unchanged
- III. Test-First - unchanged
- IV. Native macOS Fidelity and Accessibility - unchanged
- V. Observability, Diagnostics, and Error Discipline - unchanged

Added sections: none
Removed sections: none

Expanded guidance:
- Technology Stack and Toolchain: "macOS only" restated as an enforceable exclusion of
  other Apple platforms, Mac Catalyst, cross-platform UI toolkits, and cross-platform
  design pressure; the deployment target TODO is retained.

Follow-up TODOs:
- TODO(DEPLOYMENT_TARGET): minimum supported macOS version is undecided.
- TODO(SIGNING_IDENTITY): bundle identifier, signing team, notarization unknown.
- TODO(HARDWARE_SCOPE): whether the app drives CNC hardware is unstated.
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

## Technology Stack and Toolchain

- Language: Swift 6 language mode; mixing another language requires an amendment.
- Platform: macOS only, exclusively. Targets for iOS, iPadOS, tvOS, watchOS, visionOS, Mac
  Catalyst, Linux, or Windows MUST NOT be added, cross-platform UI toolkits MUST NOT be
  introduced, and no other-platform requirement MAY shape the design. The deployment target
  is TODO(DEPLOYMENT_TARGET), MUST be fixed before the first feature plan, and MUST NOT be
  raised without an amendment.
- Build: Swift Package Manager for every module. The Xcode project MUST consume the
  packages and MUST NOT duplicate their sources.
- Toolchain: current stable Xcode, pinned in CI and documented in `AGENTS.md` once CI exists.
- Formatting: `swift-format` configured at the repository root, applied to all Swift
  sources, enforced in CI. First-party targets MUST treat warnings as errors.
- Dependencies: Apple frameworks first. Every third-party package MUST be justified,
  maintained, and license-compatible with distribution outside the App Store unless stated.
- Distribution, bundle identifier, signing, and notarization are TODO(SIGNING_IDENTITY) and
  MUST be settled before a release plan is written.

## Development Workflow and Quality Gates

- Work follows `spec.md` -> `plan.md` -> `tasks.md` -> implementation. Implementation MUST
  NOT begin before `plan.md` and `tasks.md` exist.
- Every `plan.md` MUST include a Constitution Check mapping each principle to a verification
  step; a failing or skipped check blocks the plan.
- A task is complete only when its tests pass, the module builds without warnings, and
  `swift-format` lint is clean.
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
- TODO(DEPLOYMENT_TARGET), TODO(SIGNING_IDENTITY), and TODO(HARDWARE_SCOPE) MUST be
  resolved by amendment.

**Version**: 2.1.0 | **Ratified**: 2026-11-12 | **Last Amended**: 2026-11-12
