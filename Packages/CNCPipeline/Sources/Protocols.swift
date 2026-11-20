import CNCCutters
import CNCDiagnostics
import CNCGCode
import CNCMachineProfile
import CNCMaterials
import CNCSTL
import CNCSimulation
import CNCToolpath
import CNCValidation
import Foundation

/// Everything needed to run one generation job.
///
/// The request is a value snapshot: a successful run never reads the libraries, the clock, or the
/// filesystem again.
///
/// - Concurrency: Sendable snapshot safe to pass to the pipeline actor.
public struct GenerationRequest: Sendable {
    /// The decoded model, in model space.
    public let model: MeshDocument

    /// The confirmed job binding the model, stock, cutter, material, and strategy.
    public let job: JobSettings

    /// The cutter selected for this generation job.
    public let cutter: Cutter
    /// The material selected for this generation job.
    public let material: Material
    /// The machine profile constraining planning, validation, and simulation.
    public let profile: MachineProfile

    /// Where `commit` may write the program; `run` never writes to it.
    public let destination: URL

    /// The injected clock reading recorded in the header (Principle III, FR-028).
    public let generatedAt: Date

    /// Creates an immutable request snapshot from the model, job, tooling, and destination.
    public init(
        model: MeshDocument,
        job: JobSettings,
        cutter: Cutter,
        material: Material,
        profile: MachineProfile,
        destination: URL,
        generatedAt: Date
    ) {
        self.model = model
        self.job = job
        self.cutter = cutter
        self.material = material
        self.profile = profile
        self.destination = destination
        self.generatedAt = generatedAt
    }
}

/// What a supplied confirmation proves, and nothing more.
///
/// A `.ready` outcome alone is not permission to write: `commit` also requires this value
/// (spec clarification Q6, FR-064).
///
/// - Concurrency: Sendable value safe to pass to the commit gate.
public struct WriteConfirmation: Sendable, Equatable {
    /// The 3D preview was shown to the user.
    public let previewShown: Bool

    /// Every finding and simulation violation was acknowledged.
    public let findingsAcknowledged: Bool

    /// Creates a confirmation recording the two required user acknowledgements.
    public init(previewShown: Bool, findingsAcknowledged: Bool) {
        self.previewShown = previewShown
        self.findingsAcknowledged = findingsAcknowledged
    }
}

/// The outcome of one pipeline run.
///
/// `ready` carries the validated program and simulation result; the run itself writes nothing.
/// `blocked` and `cancelled` can never be committed (FR-026, FR-064, FR-069).
///
/// - Concurrency: Sendable value safe to return from an asynchronous run.
public enum PipelineOutcome: Sendable {
    /// A validated program, its report, and its simulation; eligible for preview and commit.
    case ready(RenderedProgram, ValidationReport, SimulationResult)
    /// Validation findings that prevent writing.
    case blocked([Finding])
    /// The run stopped on request; nothing was written.
    case cancelled
}

/// The orchestration boundary. `CNCPipeline` is the only package that imports every stage.
///
/// - Concurrency: Sendable boundary; both requirements are `async` and may run on an actor.
public protocol PipelineRunning: Sendable {
    /// Decodes, plans, renders, validates, and simulates, in that order, without writing a file.
    ///
    /// - Returns: `.ready` with the values the preview needs, `.blocked` with every finding, or
    ///   `.cancelled` when the run stopped on request.
    /// - Throws: A typed error only for a stage failure that is not a conformance finding.
    /// - Concurrency: `async`; implementations stop on cancellation and return `.cancelled`.
    func run(
        _ request: GenerationRequest,
        progress: ProgressSink
    ) async throws -> PipelineOutcome

    /// Writes exactly one atomically replaced `.nc` file, gated by `confirmation`.
    ///
    /// - Preconditions: the program came from a `.ready` run whose preview was shown, whose
    ///   findings were acknowledged, whose simulation completed without cancellation, and whose
    ///   validated program and simulation carry no violations or errors (FR-064, FR-066).
    /// - Throws: A typed error when the confirmation, provenance, findings, violations, or
    ///   simulation state refuses the write; the writer's error when the atomic write fails.
    /// - Concurrency: `async`; call with `await` when the runner is an actor.
    func commit(
        _ program: RenderedProgram,
        confirmation: WriteConfirmation,
        to destination: URL
    ) async throws
}
