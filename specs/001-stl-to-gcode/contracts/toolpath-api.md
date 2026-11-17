# Contract: Stage Boundaries

**Scope**: the typed interfaces between decode, material resolution, toolpath, post-processing, validation, simulation, and orchestration.

Principle VI requires typed boundaries between stages: no stage imports UI, and no view parses files or formats G-code. Below, `async throws` implies a typed error from that stage, and every long operation accepts a progress sink and honours cancellation (FR-069).

## Dependency direction

```text
MainScreenUI ──> CNCPipeline ──> CNCSTL
                      │           CNCToolpath ──> CNCGeometry
                      │                │          CNCCutters
                      │                │          CNCMaterials ──> CNCMachineProfile
                      │                │                             CNCCutters
                      │                v
                      │             CNCGCode
                      ├──────────> CNCValidation
                      ├──────────> CNCSimulation
                      ├──────────> CNCCuttersStore ──> CNCStorage
                      └──────────> CNCMaterialsStore ──> CNCStorage

CutterLibraryModalUI ──> CNCCuttersStore
```

Hard rules, enforced by a build-graph test:

- `CNCValidation` receives program text and must not import `CNCGCode`.
- `CNCToolpath` must not import `CNCGCode`, `CNCValidation`, or `CNCPipeline`; it emits abstract moves, not text.
- `CNCPipeline` is the only package that imports every stage.
- No stage package imports `CNCPipeline`, `MainScreenUI`, or `CutterLibraryModalUI`.
- `CNCMaterials` is the only place effective feed and spindle are resolved.
- Nothing below `CNCGCode` names a dialect token (FR-015).
- No domain package imports SwiftUI or RealityKit.
- Only `CNCGCode` writes files; only `CNCPipeline` and `CNCGCode` may reference a file-writing API.

## Type ownership

Each shared value type has exactly one home, so no stage has to guess where a `Move` or a `Material` comes from:

| Type | Package |
|---|---|
| `Vec3`, `Mesh`, `AABB`, `BVH`, `Transform` | `CNCGeometry` |
| `MeshDocument`, `STLModel`, `DecodeError` | `CNCSTL` |
| `MachineProfile`, `Envelope`, `StartBlock`, `StopBlock` | `CNCMachineProfile` |
| `Cutter`, `CutterType`, `CutterLibrary`, `CutterValidationError` | `CNCCutters` |
| `Material`, `MaterialLibrary`, `EffectiveCuttingValues`, `ResolutionOutcome`, `BandConflict` | `CNCMaterials` |
| `StockBlank`, `JobSettings`, `Toolpath`, `Move`, `PlanningError` | `CNCToolpath` |
| `RenderedProgram`, `GenerationRecord`, `RenderingError`, `ProgramWriter` | `CNCGCode` |
| `ParsedProgram`, `ParsedMove`, `ValidationReport`, `Finding` | `CNCValidation` |
| `SimulationResult`, `Heightmap` | `CNCSimulation` |
| `LibraryChange`, `CutterLibraryLoadOutcome` | `CNCCuttersStore` |
| `MaterialLibraryLoadOutcome` | `CNCMaterialsStore` |
| `GenerationRequest`, `PipelineOutcome`, `ToolpathService` | `CNCPipeline` |
| `ProgressSink`, `StageProgress`, `CorrelationID`, `CNCError` | `CNCDiagnostics` |

`JobSettings` lives in `CNCToolpath` because it is the planner's input contract; `CNCGCode` imports `CNCToolpath` for `JobSettings` and `Toolpath`, which is a one-way stage dependency, not a cycle.

## Decode

```swift
public protocol MeshDecoding: Sendable {
    func decode(url: URL, progress: ProgressSink) async throws -> MeshDocument
}
```

- Throws: `DecodeError.unsupported`, `.corrupt(detail:)`, `.truncated`, `.empty`, `.nonManifold`, `.degenerate`.
- Returns geometry in model units plus a `MeshDocument` carrying bounds, encoding, and defect counts.
- Never repairs, rescales, or fills holes (FR-004).

## Material resolution

```swift
public protocol MaterialResolving: Sendable {
    func resolve(
        material: Material,
        cutter: Cutter,
        profile: MachineProfile
    ) -> ResolutionOutcome
}

public enum ResolutionOutcome: Sendable, Equatable {
    case resolved(EffectiveCuttingValues)
    case noOverlap([BandConflict])
}
```

- Pure, synchronous, no IO. Deterministic for the same three inputs.
- `.noOverlap` carries the material name, the offending band, and the profile ceiling or floor that cannot be met (FR-080).
- `.resolved` returns `confirmed: false`; confirmation is a UI action on `JobSettings`, not a property of resolution.

## Planning

```swift
public protocol ToolpathPlanning: Sendable {
    func plan(
        _ job: JobSettings,
        profile: MachineProfile,
        progress: ProgressSink
    ) async throws -> Toolpath
}
```

- Preconditions: model units and orientation confirmed; cutter resolves and is valid; material resolves; effective values confirmed; rapid-rate setup confirmed; stock inside the envelope; settings confirmed.
- Throws: `PlanningError.modelOutsideStock`, `.featureTooSmall`, `.depthExceedsCuttingLength`, `.invalidStepover`, `.invalidAllowance`, `.envelopeExceeded`, `.unconfirmedEffectiveValues`, `.rapidSetupUnconfirmed`.
- Emits ordered `Move` values with `mode` (`rapid` or `cut`); cutting moves carry the job's confirmed effective feed, never the cutter record's value (FR-040).
- Pure function of its inputs; no I/O, no clock, no randomness.

## Post-processing

```swift
public protocol GCodeRendering: Sendable {
    func render(
        _ toolpath: Toolpath,
        cutter: Cutter,
        material: Material,
        job: JobSettings,
        profile: MachineProfile,
        generatedAt: Date
    ) throws -> RenderedProgram
}

public struct RenderedProgram: Sendable {
    public let text: String
    public let record: GenerationRecord
}
```

- Returns text plus the `GenerationRecord` that produced the header.
- Formats numbers with three decimals in the invariant locale (research D8).
- Enforces the 80-character limit per line and throws `RenderingError.lineTooLong` rather than emitting a line the controller would reject.
- Applies `startBlock` and `stopBlock` from the profile, with `{spindleSpeed}` substituted from `job.effective.spindle` (FR-022).
- Never writes an `F` word on a `G0` line (FR-024).
- `generatedAt` is injected; the renderer never reads the system clock (Principle III).
- Writes the file through an injected file system, atomically (FR-027).

## Validation

```swift
public protocol ProgramValidating: Sendable {
    func validate(_ text: String, profile: MachineProfile) -> ValidationReport
}

public struct ValidationReport: Sendable {
    public let findings: [Finding]
    public let program: ParsedProgram   // validated text + parsed moves
}
```

- Implemented as an independent parser; must not call `CNCGCode` (research D7).
- Takes text, not a `RenderedProgram`, so the emitter's types cannot leak into validation.
- Returns findings with severity, line number, and rule identifier; any `error` blocks writing.
- Exposes the parsed program so simulation consumes exactly what was validated (FR-065).
- Throws only for internal failure; conformance problems are findings, not thrown errors, so the UI can list them all at once.

## Simulation

```swift
public protocol MaterialRemovalSimulating: Sendable {
    func simulate(
        _ program: ParsedProgram,
        job: JobSettings,
        profile: MachineProfile,
        progress: ProgressSink
    ) async throws -> SimulationResult
}
```

- Consumes `ParsedProgram` from validation, never the emitter's `Toolpath` (FR-065).
- Rapids do not modify the heightmap (FR-063).
- Cancellation returns or throws a cancellation outcome distinguishable from failure (FR-066).

## Persistence

```swift
public protocol CutterLibraryStoring: Sendable {
    func load() async throws -> CutterLibraryLoadOutcome   // loaded, migrated(from:), absent, refused(found:), corrupt
    func save(_ library: CutterLibrary) async throws
    var changes: AsyncStream<LibraryChange> { get }
}

public protocol MaterialLibraryStoring: Sendable {
    func load() async throws -> MaterialLibraryLoadOutcome
    func save(_ library: MaterialLibrary) async throws
}
```

- `load()` reports which state occurred; it never throws for `absent` or `refused` (FR-053, FR-054).
- `save()` is atomic and preserves the previous file as a backup (FR-051).
- `changes` carries change kinds only, never records (research D14).

## Orchestration

```swift
public protocol PipelineRunning: Sendable {
    func run(_ request: GenerationRequest, progress: ProgressSink) async throws -> PipelineOutcome
}

public struct GenerationRequest: Sendable {
    public let model: MeshDocument
    public let job: JobSettings
    public let cutter: Cutter
    public let material: Material
    public let profile: MachineProfile
    public let destination: URL
    public let generatedAt: Date
}

public enum PipelineOutcome: Sendable {
    case written(RenderedProgram, ValidationReport, SimulationResult)
    case blocked([Finding])
    case cancelled
}
```

- `run` performs decode (when given a URL rather than a decoded document), plan, render, validate, simulate, write, in that order.
- Writing happens only after validation reports zero error-severity findings and simulation completes (FR-026, FR-064).
- Cancellation is its own outcome, logged in its own category and shown as cancelled, never as an error (FR-069).
- The actor owns no UI types and returns value types only.

## Progress and cancellation

```swift
public struct ProgressSink: Sendable {
    public let report: @Sendable (StageProgress) -> Void
    public let isCancelled: @Sendable () -> Bool
}
```

- Every stage checks `isCancelled` between work units and cooperates with `Task.cancel()` via `withTaskCancellationHandler` (research D10).
- Cancellation surfaces as `PipelineOutcome.cancelled`, never as a thrown conformance error (FR-069).

## Error shape

Every stage error carries a `correlationID` shared with the log record, a user-facing message naming the problem and the fix, and a machine-readable case for tests (FR-067).
