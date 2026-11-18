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
public struct GenerationRequest: Sendable {
    /// The decoded model, in model space.
    public let model: MeshDocument

    /// The confirmed job binding the model, stock, cutter, material, and strategy.
    public let job: JobSettings

    public let cutter: Cutter
    public let material: Material
    public let profile: MachineProfile

    /// Where `commit` may write the program; `run` never writes to it.
    public let destination: URL

    /// The injected clock reading recorded in the header (Principle III, FR-028).
    public let generatedAt: Date

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
public struct WriteConfirmation: Sendable, Equatable {
    /// The 3D preview was shown to the user.
    public let previewShown: Bool

    /// Every finding and simulation violation was acknowledged.
    public let findingsAcknowledged: Bool

    public init(previewShown: Bool, findingsAcknowledged: Bool) {
        self.previewShown = previewShown
        self.findingsAcknowledged = findingsAcknowledged
    }
}

/// The outcome of one pipeline run.
///
/// `ready` carries the validated program and simulation result; the run itself writes nothing.
/// `blocked` and `cancelled` can never be committed (FR-026, FR-064, FR-069).
public enum PipelineOutcome: Sendable {
    case ready(RenderedProgram, ValidationReport, SimulationResult)
    case blocked([Finding])
    case cancelled
}

/// The orchestration boundary. `CNCPipeline` is the only package that imports every stage.
public protocol PipelineRunning: Sendable {
    /// Decodes, plans, renders, validates, and simulates, in that order, without writing a file.
    ///
    /// - Returns: `.ready` with the values the preview needs, `.blocked` with every finding, or
    ///   `.cancelled` when the run stopped on request.
    /// - Throws: A typed error only for a stage failure that is not a conformance finding.
    func run(
        _ request: GenerationRequest,
        progress: ProgressSink
    ) async throws -> PipelineOutcome

    /// Writes exactly one atomically replaced `.nc` file, gated by `confirmation`.
    ///
    /// - Preconditions: the program came from a `.ready` run whose preview was shown and whose
    ///   findings were acknowledged.
    /// - Throws: A typed error when the confirmation is incomplete or the write fails.
    func commit(
        _ program: RenderedProgram,
        confirmation: WriteConfirmation,
        to destination: URL
    ) async throws
}
