# Phase 0 Research: STL to Machine-Ready G-code

**Feature**: `001-stl-to-gcode` | **Date**: 2026-11-17

All decisions below were checked against the constitution, and the toolchain claims were executed on this machine rather than assumed.

## D1. Build: SPM workspace plus a bundle script, no Xcode project

**Decision**: The workspace is a root `Package.swift` aggregating one package per module under `Packages/`, plus an executable target `CNCswiftApp`. `Scripts/make-app.sh` assembles `CNCswift.app` from the built executable, an `Info.plist`, and an entitlements file, then ad-hoc signs it with `/usr/bin/codesign --sign -`. Under constitution v4.3.0 this is the mandated local signing path for SPM/Command Line Tools bundles; an Xcode build, when one is used, uses Xcode's default local signing. No distributable, App Store, Developer ID, or notarized artifact is produced.

**Rationale**: Verified: `xcodebuild` is unavailable because the active developer directory is `/Library/Developer/CommandLineTools`, and no Xcode is installed. A checked-in `.xcodeproj` could be written but never opened, built, or verified here, which would violate the rule against unverifiable output. `swift build` and `swift test` from the repository root cover every module, and `Package.swift` opens as a project wherever Xcode exists later, with no duplicated sources.

**Alternatives considered**: Hand-written `project.pbxproj` (unverifiable, error-prone, and duplicates configuration); XcodeGen or Tuist (third-party build dependencies against Principle II's justification rule, for a problem that does not exist yet); making the app a plain executable without a bundle (sandbox entitlements and `Info.plist` keys such as the bundle identifier cannot be applied, so the app could not satisfy Principles IV and VII).

## D2. Testing: Swift Testing with an explicit macro-plugin path

**Decision**: Every module gets a Swift Testing test target. The documented test command is:

```bash
swift test -Xswiftc -load-plugin-library \
  -Xswiftc "$(xcode-select -p)/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
```

`Scripts/ci.sh` resolves that path once and passes it to every `swift test` invocation.

**Rationale**: Verified failure: a bare `swift test` with `import Testing` fails with `external macro implementation type 'TestingMacros.TestDeclarationMacro' could not be found ... plugin for module 'TestingMacros' not found`. The plugin exists at `/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib`, but SwiftPM only loads `host/plugins/libSwiftMacros.dylib`. Passing `-load-plugin-library` for the testing plugin makes tests build and pass — verified with a real `@Test`/`#expect` round trip.

**Alternatives considered**: XCTest (rejected: absent from the CLT toolchain — there is no `XCTest.framework` under the CLT developer frameworks — and Principle III mandates Swift Testing for new tests); installing Xcode (correct long-term, but outside this feature's scope and not required once the flag is documented).

## D3. 3D preview: RealityKit, not SceneKit

**Decision**: Render the material-removal preview with RealityKit through SwiftUI's `RealityView`, building a custom mesh with `MeshDescriptor`/`MeshResource` from a z-map. Qualify SwiftUI's scene protocol as `SwiftUI.Scene` in the app target.

**Rationale**: Verified: SceneKit is deprecated across all platforms from macOS 26 onward and is in maintenance mode; the deployment floor is macOS 27.0. Building a new feature on a maintenance-mode framework conflicts with Principle IV's intent. RealityKit is the recommended successor and is present in the `MacOSX27.2.sdk`. Verified compilation: a `RealityView` with a generated `MeshResource` links successfully with `-parse-as-library -swift-version 6 -strict-concurrency=complete -target arm64-apple-macos27.0` under CLT.

Also verified: importing RealityKit and SwiftUI together makes `Scene` ambiguous (`SwiftUI.Scene` vs `RealityKit.Scene`), so `App` bodies must spell `SwiftUI.Scene`. This is recorded as a known friction point rather than discovered during implementation.

**Alternatives considered**: SceneKit (deprecated); MetalKit with a hand-written render pipeline (most control, far more code — camera, depth, shaders — for a preview that shows a heightfield); a 2D path plot (rejected by the user's decision that version 1 must show material removal).

## D4. STL decoding: first-party, strict, both encodings

**Decision**: `CNCSTL` decodes both ASCII and binary STL itself, with no dependency on model IO frameworks. Detection is content-based (binary files carry an 84-byte header plus a `uint32` triangle count and a fixed record size; the file length must equal `84 + 50 * count`), not extension-based. Decoding produces a `Mesh` of triangles in model units, plus a manifest of defects.

**Rationale**: Principle VI forbids silent repair and requires rejection of corrupt, empty, non-manifold, and unsupported inputs. A first-party decoder makes every rejection reason explicit and testable, and avoids the ambiguity of a general-purpose importer that repairs or rescales geometry as a side effect. Content-based detection is required because the STL format has no reliable magic number.

**Alternatives considered**: Model IO (repairs and rescales internally, and reports success on inputs the spec requires rejecting); a third-party parser (dependency without justification); trusting the file extension (a `.stl` file is not guaranteed to be either encoding).

## D5. Geometry queries: BVH ray casting with drop-cutter correction

**Decision**: `CNCGeometry` builds a bounding-volume hierarchy over the mesh and answers two queries: surface height at an (x, y) point (ray cast along -Z, taking the highest hit), and local triangle context for the cutter centre. The cutter's contact height is computed as a drop-cutter operation against the triangles under its footprint, giving flat, ball-nose, and V-bit cutters their correct vertical offset.

**Rationale**: Raster finishing needs the surface height at sample points, and a naive per-sample linear scan over 200,000 triangles would be too slow for the 5-minute budget. A BVH reduces each query to O(log n). Drop-cutter correction is required because a ball-nose and a V-bit contact the surface at a different height than a flat cutter at the same centre point; using the surface height directly would gouge the model.

**Alternatives considered**: Exact B-rep offset surfaces and waterline slicing (exact but far more complex, with self-intersection handling and determinism risks); a coarse heightmap sampled once and reused (introduces a fixed discretisation error that can cut deeper than intended, and Principle VI requires geometry the profile cannot represent to fail rather than be approximated silently).

## D6. Toolpath: layered roughing then raster finishing

**Decision**: Roughing removes material in horizontal layers, deepest first from the stock top down to the finishing allowance, at the user's maximum depth per pass. Each layer's cleared region is the model silhouette at that level, offset outward by the cutter radius and clipped to the stock; the region is filled with raster passes at the user's stepover. Finishing is a raster pass over the model's footprint plus exactly one cutter radius of margin, at stepover resolution, with each point's Z taken from a drop-cutter query. Rapid moves between passes occur at the profile's clearance height. Every cutting move carries the job's confirmed effective feed rate, not the cutter record's raw value.

**Rationale**: This is the user-confirmed strategy, and it is the simplest correct approach that produces a real two-stage toolpath. Deriving the roughing region from the silhouette per layer (rather than rastering the whole blank) satisfies FR-038 and keeps the file small. Determinism follows from a fixed raster origin and a fixed traversal order. Taking the rate from the job rather than the cutter record is required by FR-040 and FR-079.

**Alternatives considered**: Waterline/contour-parallel finishing (better load distribution, but offset-curve self-intersection is the hardest part of the whole pipeline); adaptive clearing (superior, but a large algorithm outside this feature's scope); raster roughing over the whole blank (simple but wasteful and violates FR-038).

## D7. Validation: an independent GRBL 1.1 parser

**Decision**: `CNCValidation` implements its own line grammar for the GRBL 1.1 subset and runs semantic rules over the parsed program: envelope containment, feed ceiling, spindle range, modal state consistency, block order, `M30` last, no feed word on a rapid, and the 80-character line limit. It accepts program **text** as a `String` and must not import `CNCGCode`. Its result exposes the parsed move list so simulation can consume the validated program without a second parser.

**Rationale**: Principle VI requires validation before writing. A validator that shares the emitter's formatting code would re-assert the emitter's own assumptions and would not catch a malformed line. A separate parser acts as a second opinion, and the `String` boundary makes the separation structural rather than a convention. Exposing parsed moves keeps FR-065 ("simulate the same validated program") honest: simulation reads what the validator accepted, not the emitter's in-memory toolpath.

**Alternatives considered**: Reusing the emitter's model (cannot detect emitter bugs); a regex conformance scan (cannot check modal state, so it cannot know the effective feed or units at a given line); shipping a third-party G-code parser (unjustified dependency, and availability for GRBL 1.1 specifically is poor); having simulation parse the text itself (duplicate parser, two chances to disagree).

## D8. Output formatting: deterministic, 80 characters per line

**Decision**: Lines are UTF-8, terminated with `\n`. Coordinates and feeds are formatted with exactly three decimal places in the invariant locale, with no exponent and no locale separators. Every emitted line, including comments and the header, is at most 80 characters. The header uses `;` comments, one short fact per line. `generatedAt` is an injected `Date`, never read from the system clock inside the emitter.

**Rationale**: Verified: GRBL's line buffer is 80 characters (`LINE_BUFFER_SIZE` in `protocol.h`) and a longer line fails with `error:11 — max characters per line exceeded`, aborting that line mid-program. This is a hard emitter constraint the spec did not anticipate, so it becomes both a contract and a validation rule. Fixed formatting and `\n` endings are what make FR-028's byte-identical output achievable, and an injected clock is the only way to test that determinism without real time (Principle III).

**Alternatives considered**: Free-form `Double` description (produces `1e-05` and locale-dependent output, breaking determinism); long descriptive header lines (would break the 80-character rule and stall the job at the controller); `\r\n` endings (accepted by GRBL but unnecessary and inconsistent across platforms); reading `Date()` inside the renderer (untestable determinism).

## D9. Persistence: versioned JSON with atomic replace and forward-only migrations

**Decision**: The cutter library and the material library are separate JSON documents in Application Support, each carrying `schemaVersion`. Both are written through one `CNCStorage` package: temporary sibling file, atomic replace via `FileManager.replaceItemAt`, previous file retained as backup, and a migration runner that steps forward one version at a time. A file with a newer version than the app knows is refused and left byte-identical.

**Rationale**: Principle VII requires atomic writes, a versioned schema, tested forward migrations, and no destructive migration. Two libraries needing identical durability guarantees is exactly the case for one shared implementation; two copies would drift at the first bug fix. JSON is inspectable, diffable in fixtures, and needs no extra dependency.

**Alternatives considered**: SwiftData or Core Data (opaque store, heavier migration story, and a framework whose model changes are harder to fixture-test); a single binary archive (not inspectable, brittle across schema change); writing in place (violates atomicity and can lose the library on a crash); duplicating atomic-write code in each store (two contracts to keep in sync).

## D10. Concurrency: one generation actor, cancellable progress streams

**Decision**: Decoding, planning, emitting, validation, and simulation run inside a `ToolpathService` actor in `CNCPipeline`. Each long operation accepts an `AsyncStream<Progress>` for reporting and honours `Task.cancel()` through `withTaskCancellationHandler`. View models are `@MainActor`. Errors are typed per stage and carry a correlation identifier shared between the user message and the `os.Logger` record.

**Rationale**: Principle I forbids blocking work on the main actor and requires structured, cancellable concurrency with no `Task.detached`. An actor gives one serialisation point for pipeline state without `@unchecked Sendable`. Cancellation must be distinguishable from failure (FR-069), so cancellation is surfaced as its own typed outcome and its own log category. Placing the actor in `CNCPipeline` rather than `CNCToolpath` keeps the planner free of emitter and validator imports.

**Alternatives considered**: `Task.detached` per stage (ungoverned lifetimes, and cancellation does not propagate); an `OperationQueue` (pre-Swift-concurrency idiom, and shared mutable state would need locks); doing the work on the main actor with progress callbacks (blocks the UI for minutes on a 200k-triangle model).

## D11. Material bands and effective-value resolution

**Decision**: `CNCMaterials` owns the `Material` value type, the four built-in presets, band validation, and one resolution function:

```swift
EffectiveCuttingValues.resolve(material:cutter:profile:)
  -> .resolved(EffectiveCuttingValues)   // feed + spindle
  -> .noOverlap(reason)                  // names the unsatisfiable constraint
```

Resolution intersects the material's feed band and spindle band with the profile's limits. The cutter's recorded value is the prefill when it lies inside the intersection; otherwise the nearest bound is offered. The UI must show both values and require explicit confirmation; a value outside the intersection is rejected. Empty intersections are refused before generation (FR-080).

Provisional preset bands, all inside the 800 mm/min and 5,000-8,000 RPM limits:

| Preset | Feed band (mm/min) | Spindle band (RPM) |
|---|---|---|
| Softwood (pine/basswood) | 600-800 | 7,000-8,000 |
| Hardwood (oak/maple) | 400-600 | 7,000-8,000 |
| MDF | 500-700 | 7,000-8,000 |
| Plywood | 500-700 | 7,000-8,000 |

**Rationale**: FR-077 – FR-081 need one testable home. Putting resolution in the planner would hide FR-080 behind toolpath preconditions, and putting it in the UI would make it untestable without SwiftUI. The four presets match the clarified scope: wood and wood composites only. The band values are engineering guidance for a 500 W-class spindle, not certified cutting data, and remain adjustable per job by design.

**Alternatives considered**: Material owning final values (unsafe: a 3 mm and a 6 mm cutter would get identical rates); storing bands on the cutter (the previous spec: the same cutter record would need duplicating per material); letting the planner clamp into range (violates the no-clamping rule in FR-078 and FR-080).

**Review gate (not a design unknown)**: the band numbers above are provisional engineering guidance. `Fixtures/materials/README.md` MUST record cutting-experience sign-off before the preset fixture is treated as production data (task T111). Until then the fixture is marked provisional; per-job user confirmation remains mandatory and generation is not blocked by the pending review.

## D12. Rapid rate: controller settings, not program text

**Decision**: The profile declares `rapidRateSetup` — the controller settings `$110 = 800`, `$111 = 800`, `$112 = 800` — plus `maxRapidRate: 800` as the value those settings must produce. The emitter never writes an `F` word on a `G0` line. The main screen requires the operator to confirm the settings once per session before generation is enabled, and the header records that the rapid rate is controller-set. Validation rejects any feed word appearing on a rapid line.

**Rationale**: Verified against GRBL 1.1 behaviour: `G0` ignores `F`, so a rapid's rate is decided entirely by `$110`–`$112`. Writing `F800` on a rapid would be a lie the controller ignores, and writing every traverse as `G1` would slow the job and still leave the mandated `G00 Z10.0` lines outside the guarantee. The constitution already treats `$30`/`$31` as machine setup rather than app behaviour, so this follows established precedent. Constitution v4.1.0 ratifies it as a controller-setting requirement, retained through v4.3.0; the plan records it as such.

**Alternatives considered**: Emitting every traverse as `G1` at 800 mm/min (honest in the file, but slower, longer, and inconsistent with the fixed start and stop blocks that use `G00`); keeping the rejection rule as written (unenforceable: there is no rate on a `G0` line to reject); silently ignoring the ceiling (violates the intent outright).

## D13. Orchestration boundary: a `CNCPipeline` package

**Decision**: `ToolpathService` and `PipelineOutcome` live in a new `CNCPipeline` package that depends on every stage and both stores. The app target constructs it; `MainScreenUI` calls it.

**Rationale**: The earlier plan placed orchestration in `CNCToolpath`, which would force the planner to import `CNCGCode` and `CNCValidation` — both explicitly forbidden by `contracts/toolpath-api.md` and by Principle VI's typed stage boundaries. A dedicated package keeps the forbidden edges absent by construction and gives the end-to-end and cancellation tests a home that does not link SwiftUI.

**Alternatives considered**: Orchestration in the app target (untestable without launching the app, and the app target would accumulate pipeline logic); orchestration in `MainScreenUI` (couples generation to presentation, violating "no view parses files"); orchestration split across stage packages (no single cancellation owner).

## D14. Cutter-deletion propagation without shared mutable state

**Decision**: `CNCCuttersStore` is an actor that publishes an `AsyncStream<LibraryChange>` (`.saved`, `.deleted(id:)`, `.reloaded`). The composition root creates exactly one store and injects it into both presentation modules. `MainScreenUI` subscribes, re-resolves its selected cutter identifier after a change, and clears the selection when it no longer resolves, blocking generation until another stored cutter is chosen (FR-060).

**Rationale**: FR-058 forbids shared mutable in-memory state and makes the persisted library the only contract. A stream from the store is a notification about the persisted document, not a second source of truth, and it keeps the two presentation modules from importing each other (FR-059). The same mechanism makes the cutter-edit contract test (SC-007) deterministic: the test drives the store and observes the stream.

**Alternatives considered**: `NotificationCenter` with an untyped name (no payload, no compile-time safety, and hard to await in tests); polling the file (latency, wasted IO, and a race with in-flight writes); a shared observable object (exactly the shared mutable state FR-058 prohibits); direct modal-to-main-screen reference (violates FR-057 and FR-059).

## Verified commands

These are the commands the implementation must document in `AGENTS.md`; each was executed here except where noted as pending implementation.

| Purpose | Command | Verified |
|---|---|---|
| Build | `swift build` | yes (trivial package) |
| Test | `swift test -Xswiftc -load-plugin-library -Xswiftc <CLT>/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib` | yes (passing `@Test`) |
| Format lint | `swift format lint --recursive Packages App` | binary present; flags to confirm at implementation |
| Format write | `swift format --in-place --recursive Packages App` | binary present; flags to confirm at implementation |
| Bundle app | `Scripts/make-app.sh` | pending implementation |
| Ad-hoc sign + sandbox check | `codesign -dvv .build/CNCswift.app` and `codesign -d --entitlements :- .build/CNCswift.app` | pending implementation |
| Run | `open .build/CNCswift.app` | pending implementation |

## Open items carried into implementation

- Swift Testing's plugin path must be resolved dynamically in `Scripts/ci.sh` rather than hardcoded to a Command Line Tools path, so it still works if Xcode is installed later.
- `swift format` subcommand flags need confirmation against the actual configuration file at implementation time.
- Ad-hoc signing (`/usr/bin/codesign --sign -`) is mandated for SPM/CLT app bundles by constitution v4.3.0. The first bundle build MUST verify that the ad-hoc signature is valid and that the sandbox entitlement is present and effective. A launch failure MUST be diagnosed and fixed inside an ad-hoc-signed, sandboxed bundle; dropping the sandbox entitlement is prohibited by Principle IV, and an unresolvable failure blocks the build and is reported as a finding rather than waived.
- The provisional material band table in D11 needs a review sign-off before the preset fixture is treated as production data.
- The 80-character ceiling is derived from GRBL's `LINE_BUFFER_SIZE` and is now traceable as FR-082; it is enforced by the formatter and re-checked by the validator.
- The rapid-rate rule in D12 is ratified in constitution v4.1.0 and retained through v4.3.0 as a controller-setting requirement; the plan records it as such.
