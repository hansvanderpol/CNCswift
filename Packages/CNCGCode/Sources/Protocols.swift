import CNCCutters
import CNCMachineProfile
import CNCMaterials
import CNCToolpath
import Foundation

/// What one rendered program was produced from, in the order the header states it (FR-029).
///
/// The record holds value snapshots, so a generated file stays reproducible after the cutter or
/// material library is edited. `generatedAt` is injected; it is the only field that may vary
/// between two renders of the same inputs (FR-028).
///
/// - Concurrency: `Sendable` value type; safe to share across concurrency boundaries.
public struct GenerationRecord: Sendable, Equatable {
    /// A snapshot of the cutter used for the program.
    public let cutter: Cutter
    /// A snapshot of the material used for the program.
    public let material: Material
    /// A snapshot of the job settings used for the program.
    public let job: JobSettings
    /// A snapshot of the machine profile used for the program.
    public let profile: MachineProfile
    /// The model scale recorded in the header.
    public let appliedScale: Double
    /// The model basename recorded in the header.
    public let modelFileName: String
    /// The injected generation timestamp used in the header.
    public let generatedAt: Date

    /// Creates a record from the value snapshots that produced a program.
    public init(
        cutter: Cutter,
        material: Material,
        job: JobSettings,
        profile: MachineProfile,
        appliedScale: Double,
        modelFileName: String,
        generatedAt: Date
    ) {
        self.cutter = cutter
        self.material = material
        self.job = job
        self.profile = profile
        self.appliedScale = appliedScale
        self.modelFileName = modelFileName
        self.generatedAt = generatedAt
    }
}

/// The program text and the record that produced its header.
///
/// - Concurrency: `Sendable` value type; safe to share across concurrency boundaries.
public struct RenderedProgram: Sendable, Equatable {
    /// 7-bit ASCII text, `\n` line endings, one trailing newline after `M30` (FR-018, FR-021).
    public let text: String
    /// The record that produced the program text.
    public let record: GenerationRecord

    /// Creates a rendered program from its text and generation record.
    ///
    /// - Precondition: `text` is 7-bit ASCII G-code with `\n` endings and one trailing newline.
    public init(text: String, record: GenerationRecord) {
        self.text = text
        self.record = record
    }
}

/// Machine-readable reasons rendering was refused.
///
/// Rendering throws rather than emitting a line the controller would reject (FR-082).
///
/// - Concurrency: `Sendable` error value; safe to share across concurrency boundaries.
public enum RenderingError: Error, Equatable, Sendable {
    /// A line would exceed the profile's maximum line length.
    case lineTooLong(lineNumber: Int, length: Int)

    /// A line contains a byte outside 7-bit ASCII.
    case nonASCIILine(lineNumber: Int)

    /// A profile template placeholder had no value.
    case missingTemplateValue(String)

    /// The toolpath had no moves to render.
    case emptyToolpath
}

/// The post-processing stage boundary.
///
/// - Concurrency: Conformers are `Sendable` and may be shared across concurrency boundaries.
public protocol GCodeRendering: Sendable {
    /// Renders the toolpath as GRBL 1.1 text plus its generation record.
    ///
    /// - Throws: `RenderingError` when a line cannot be emitted within the contract.
    /// - Note: Does not write a file; only `PipelineRunning.commit` may call `ProgramWriter`.
    func render(
        _ toolpath: Toolpath,
        cutter: Cutter,
        material: Material,
        job: JobSettings,
        profile: MachineProfile,
        generatedAt: Date
    ) throws -> RenderedProgram
}

/// The only file-writing API in the workspace (FR-027, C2).
///
/// Invoked solely from `PipelineRunning.commit`, which writes one atomically replaced `.nc` file
/// after a preview was shown and findings were acknowledged.
///
/// - Concurrency: Conformers are `Sendable` and may be shared across concurrency boundaries.
public protocol ProgramWriter: Sendable {
    /// Writes `program` to `url` as one atomic replacement.
    ///
    /// - Throws: A writer error when the file cannot be produced. No partial file is left behind.
    /// - Concurrency: `async`; checks cancellation before exposing a written file.
    func write(_ program: RenderedProgram, to url: URL) async throws
}
